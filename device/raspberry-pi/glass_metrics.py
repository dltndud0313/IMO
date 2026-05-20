"""Exercise-specific heuristics for glass HUD rendering."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from esp32_serial_receiver import DecodedFrame

EMG_DETACHED_THRESHOLD = 0.99

# Fixed channel contract used across app / Pi / glass HUD:
# - EMG1: left prime mover
# - EMG2: right prime mover
# - EMG3: left assist / compensator
# - EMG4: right assist / compensator
# - IMU1: left arm
# - IMU2: right arm
# - IMU3: torso
# Exercise type changes the semantic meaning of each fixed channel.

SENSOR_CONFIGS = {
    "pushup": [
        ("EMG 1", "Left pectoralis major"),
        ("EMG 2", "Right pectoralis major"),
        ("EMG 3", "Left triceps"),
        ("EMG 4", "Right triceps"),
        ("IMU 1", "Left upper arm outer side"),
        ("IMU 2", "Right upper arm outer side"),
        ("IMU 3", "Upper thoracic / torso center"),
    ],
    "lateral_raise": [
        ("EMG 1", "Left lateral deltoid"),
        ("EMG 2", "Right lateral deltoid"),
        ("EMG 3", "Left upper trapezius"),
        ("EMG 4", "Right upper trapezius"),
        ("IMU 1", "Left wrist / forearm"),
        ("IMU 2", "Right wrist / forearm"),
        ("IMU 3", "Upper thoracic / back center"),
    ],
    "bicep_curl": [
        ("EMG 1", "Left biceps"),
        ("EMG 2", "Right biceps"),
        ("EMG 3", "Left forearm"),
        ("EMG 4", "Right forearm"),
        ("IMU 1", "Left wrist / forearm"),
        ("IMU 2", "Right wrist / forearm"),
        ("IMU 3", "Upper torso / chest center"),
    ],
}


@dataclass(frozen=True)
class HeuristicResult:
    activation_percent: int
    channel_activation_percent: list[Optional[int]]
    activation_level: str
    usage_text: str
    usage_tone: str
    pose_badge: str
    pose_title: str
    pose_detail: str
    pose_tone: str


@dataclass(frozen=True)
class FrameFeatures:
    left_primary: float
    left_primary_detached: bool
    right_primary: float
    right_primary_detached: bool
    left_secondary: float
    left_secondary_detached: bool
    right_secondary: float
    right_secondary_detached: bool
    primary_avg: float
    secondary_avg: float
    primary_gap: float
    secondary_gap: float
    left_arm_motion: float
    right_arm_motion: float
    arm_motion_gap: float
    left_arm_accel_change: float
    right_arm_accel_change: float
    arm_accel_gap: float
    torso_motion: float
    torso_tilt: float
    motion_detected: bool
    detached_emg_channels: int


def _activation_level(level: float) -> str:
    if level >= 0.55:
        return "HIGH"
    if level >= 0.22:
        return "MEDIUM"
    return "LOW"


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def _gyro_norm(gyro: tuple[float, float, float]) -> float:
    return abs(gyro[0]) + abs(gyro[1]) + abs(gyro[2])


def _accel_delta_norm(accel: tuple[float, float, float]) -> float:
    return abs(accel[0]) + abs(accel[1]) + abs(accel[2])


def _normalize_emg_channel(value: float, baseline: float) -> tuple[float, bool]:
    if value >= EMG_DETACHED_THRESHOLD:
        return 0.0, True
    return max(0.0, value - baseline), False


def _normalize_emg_ratio(value: float, baseline: float, mvc: float) -> float:
    denominator = max(mvc - baseline, 1e-6)
    return _clamp01((value - baseline) / denominator)


def _extract_features(frame: DecodedFrame, calibration: Optional[Any]) -> FrameFeatures:
    emg = frame.emg
    imu_gyros = list(frame.imu_gyros)
    imu_accels = list(frame.imu_accels)

    zero_vec = (0.0, 0.0, 0.0)
    while len(imu_gyros) < 3:
        imu_gyros.append(zero_vec)
    while len(imu_accels) < 3:
        imu_accels.append(zero_vec)

    emg_baseline = [0.0, 0.0, 0.0, 0.0]
    emg_mvc = [1.0, 1.0, 1.0, 1.0]
    imu_accel_baseline = [[0.0, 0.0, 0.0] for _ in range(3)]
    imu_gyro_baseline = [[0.0, 0.0, 0.0] for _ in range(3)]
    if calibration is not None and getattr(calibration, "ready", False):
        emg_baseline = list(calibration.emg_rest_baseline)
        emg_mvc = list(getattr(calibration, "emg_mvc", emg_mvc))
        imu_accel_baseline = [list(v) for v in calibration.imu_rest_accel]
        imu_gyro_baseline = [list(v) for v in calibration.imu_rest_gyro]

    left_primary, left_primary_detached = _normalize_emg_channel(emg[0], emg_baseline[0])
    right_primary, right_primary_detached = _normalize_emg_channel(emg[1], emg_baseline[1])
    left_secondary, left_secondary_detached = _normalize_emg_channel(emg[2], emg_baseline[2])
    right_secondary, right_secondary_detached = _normalize_emg_channel(emg[3], emg_baseline[3])

    if not left_primary_detached:
        left_primary = _normalize_emg_ratio(emg[0], emg_baseline[0], emg_mvc[0])
    if not right_primary_detached:
        right_primary = _normalize_emg_ratio(emg[1], emg_baseline[1], emg_mvc[1])
    if not left_secondary_detached:
        left_secondary = _normalize_emg_ratio(emg[2], emg_baseline[2], emg_mvc[2])
    if not right_secondary_detached:
        right_secondary = _normalize_emg_ratio(emg[3], emg_baseline[3], emg_mvc[3])
    primary_avg = (left_primary + right_primary) / 2.0
    secondary_avg = (left_secondary + right_secondary) / 2.0

    adj_imu_accels = []
    adj_imu_gyros = []
    for imu_index in range(3):
        adj_imu_accels.append(
            (
                imu_accels[imu_index][0] - imu_accel_baseline[imu_index][0],
                imu_accels[imu_index][1] - imu_accel_baseline[imu_index][1],
                imu_accels[imu_index][2] - imu_accel_baseline[imu_index][2],
            )
        )
        adj_imu_gyros.append(
            (
                imu_gyros[imu_index][0] - imu_gyro_baseline[imu_index][0],
                imu_gyros[imu_index][1] - imu_gyro_baseline[imu_index][1],
                imu_gyros[imu_index][2] - imu_gyro_baseline[imu_index][2],
            )
        )

    left_arm_motion = _gyro_norm(adj_imu_gyros[0])
    right_arm_motion = _gyro_norm(adj_imu_gyros[1])
    left_arm_accel_change = _accel_delta_norm(adj_imu_accels[0])
    right_arm_accel_change = _accel_delta_norm(adj_imu_accels[1])
    torso_motion = _gyro_norm(adj_imu_gyros[2])

    return FrameFeatures(
        left_primary=left_primary,
        left_primary_detached=left_primary_detached,
        right_primary=right_primary,
        right_primary_detached=right_primary_detached,
        left_secondary=left_secondary,
        left_secondary_detached=left_secondary_detached,
        right_secondary=right_secondary,
        right_secondary_detached=right_secondary_detached,
        primary_avg=primary_avg,
        secondary_avg=secondary_avg,
        primary_gap=abs(left_primary - right_primary),
        secondary_gap=abs(left_secondary - right_secondary),
        left_arm_motion=left_arm_motion,
        right_arm_motion=right_arm_motion,
        arm_motion_gap=abs(left_arm_motion - right_arm_motion),
        left_arm_accel_change=left_arm_accel_change,
        right_arm_accel_change=right_arm_accel_change,
        arm_accel_gap=abs(left_arm_accel_change - right_arm_accel_change),
        torso_motion=torso_motion,
        torso_tilt=abs(adj_imu_accels[2][0]) + abs(adj_imu_accels[2][1]),
        motion_detected=bool(frame.flags & 0x04),
        detached_emg_channels=sum(
            (
                left_primary_detached,
                right_primary_detached,
                left_secondary_detached,
                right_secondary_detached,
            )
        ),
    )


def _channel_activation_percent(features: FrameFeatures) -> list[Optional[int]]:
    channels = [
        (features.left_primary, features.left_primary_detached),
        (features.right_primary, features.right_primary_detached),
        (features.left_secondary, features.left_secondary_detached),
        (features.right_secondary, features.right_secondary_detached),
    ]
    return [
        None if detached else int(round(_clamp01(value) * 100.0))
        for value, detached in channels
    ]


def _detached_channel_indices(features: FrameFeatures) -> list[int]:
    detached_flags = [
        features.left_primary_detached,
        features.right_primary_detached,
        features.left_secondary_detached,
        features.right_secondary_detached,
    ]
    return [
        index + 1 for index, detached in enumerate(detached_flags) if detached
    ]


def _should_block_for_detached_channels(features: FrameFeatures) -> bool:
    primary_detached_count = sum(
        (features.left_primary_detached, features.right_primary_detached)
    )
    return primary_detached_count >= 2 or features.detached_emg_channels >= 3


def _apply_partial_detached_warning(
    result: HeuristicResult,
    features: FrameFeatures,
) -> HeuristicResult:
    if features.detached_emg_channels <= 0:
        return result

    detached_channels = ", ".join(
        f"EMG {index}" for index in _detached_channel_indices(features)
    )
    return HeuristicResult(
        activation_percent=result.activation_percent,
        channel_activation_percent=result.channel_activation_percent,
        activation_level=result.activation_level,
        usage_text="일부 EMG 채널 접촉이 불안정하지만 측정은 계속 진행합니다.",
        usage_tone="warn",
        pose_badge="Sensor",
        pose_title="일부 센서 접촉 불안정",
        pose_detail=(
            f"{detached_channels} 값이 1.000으로 감지되었습니다. "
            "운동은 계속 측정하되, 해당 패드 부착 상태를 확인해주세요."
        ),
        pose_tone="warn",
    )


def build_waiting_result() -> HeuristicResult:
    return HeuristicResult(
        activation_percent=0,
        channel_activation_percent=[None, None, None, None],
        activation_level="LOW",
        usage_text="운동 선택 후 근활성 판단이 시작됩니다.",
        usage_tone="neutral",
        pose_badge="System",
        pose_title="앱에서 운동을 선택하세요",
        pose_detail="센서 위치 안내를 확인한 뒤 부착 완료와 캘리브레이션을 진행하세요.",
        pose_tone="neutral",
    )


def build_phase_result(phase: str) -> Optional[HeuristicResult]:
    if phase == "ready_for_calibration":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="센서 부착 완료를 기다리는 중입니다.",
            usage_tone="warn",
            pose_badge="Ready",
            pose_title="센서 부착 확인",
            pose_detail="앱에서 센서 부착 완료를 누른 뒤 캘리브레이션을 시작하세요.",
            pose_tone="warn",
        )
    if phase == "sensors_ready":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="센서 위치 확인 완료. 기준값 측정 준비가 됐습니다.",
            usage_tone="good",
            pose_badge="Ready",
            pose_title="캘리브레이션 준비",
            pose_detail="움직이기 전에 기준값 측정을 시작하세요.",
            pose_tone="good",
        )
    if phase == "calibrating":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="캘리브레이션 중에는 최대한 같은 자세를 유지하세요.",
            usage_tone="warn",
            pose_badge="Calibrating",
            pose_title="기준값 측정 중",
            pose_detail="움직임을 최소화하고 센서가 흔들리지 않도록 유지하세요.",
            pose_tone="warn",
        )
    if phase == "calibrating_mvc":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="최대 수축 기준값을 측정 중입니다. 안내된 자세로 강하게 힘을 주세요.",
            usage_tone="warn",
            pose_badge="MVC",
            pose_title="최대 수축 측정 중",
            pose_detail="운동별 목표 근육에 최대한 힘을 준 상태를 잠시 유지하세요.",
            pose_tone="warn",
        )
    if phase == "resting":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="세트가 끝났습니다. 다음 세트를 위해 호흡을 정리하세요.",
            usage_tone="good",
            pose_badge="Rest",
            pose_title="세트 간 휴식 중",
            pose_detail="휴식이 끝나면 자동으로 다음 세트 측정이 다시 시작됩니다.",
            pose_tone="good",
        )
    if phase == "paused":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="운동이 일시정지되었습니다.",
            usage_tone="neutral",
            pose_badge="Paused",
            pose_title="운동 일시정지",
            pose_detail="앱에서 운동 재개를 누르면 다시 측정과 카운팅이 시작됩니다.",
            pose_tone="neutral",
        )
    if phase == "completed":
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=[None, None, None, None],
            activation_level="LOW",
            usage_text="운동이 종료되었습니다.",
            usage_tone="neutral",
            pose_badge="Done",
            pose_title="세션 종료",
            pose_detail="앱에서 결과를 확인하거나 다음 운동을 준비하세요.",
            pose_tone="good",
        )
    return None


def _analyze_pushup(features: FrameFeatures) -> HeuristicResult:
    level = max(features.primary_avg, features.secondary_avg * 0.85)

    if features.primary_avg < 0.05:
        usage_text = "좌우 대흉근 활성도가 아직 낮습니다."
        usage_tone = "warn"
    elif features.primary_gap > 0.18:
        usage_text = "좌우 가슴 사용 균형이 무너집니다."
        usage_tone = "danger"
    elif features.arm_accel_gap > 0.55:
        usage_text = "좌우 팔의 내려간 시작 자세 대비 움직임 차이가 큽니다."
        usage_tone = "warn"
    elif features.secondary_gap > 0.20:
        usage_text = "좌우 삼두 사용 차이가 큽니다."
        usage_tone = "warn"
    else:
        usage_text = "가슴과 삼두 사용 균형이 양호합니다."
        usage_tone = "good"

    if features.torso_tilt > 0.65:
        pose = ("Posture", "상체 정렬 주의", "몸통 기울어짐이 큽니다. 머리부터 발끝까지 일직선을 유지하세요.", "danger")
    elif features.torso_motion > 10.0:
        pose = ("Control", "몸통 흔들림 감지", "코어를 더 단단히 고정하고 반동을 줄여보세요.", "warn")
    elif features.arm_accel_gap > 0.55:
        pose = ("Balance", "좌우 팔 높이 차이", "양팔이 시작 자세 대비 비슷한 높이로 이동하는지 확인하세요.", "warn")
    elif features.arm_motion_gap > 7.0:
        pose = ("Balance", "좌우 팔 속도 차이", "양팔이 같은 속도로 밀어내는지 확인하세요.", "warn")
    else:
        pose = ("Posture", "자세 안정적", "몸통 정렬과 좌우 팔 밸런스가 안정적입니다.", "good")

    return HeuristicResult(
        activation_percent=int(round(_clamp01(level) * 100.0)),
        channel_activation_percent=_channel_activation_percent(features),
        activation_level=_activation_level(level),
        usage_text=usage_text,
        usage_tone=usage_tone,
        pose_badge=pose[0],
        pose_title=pose[1],
        pose_detail=pose[2],
        pose_tone=pose[3],
    )


def _analyze_bicep_curl(features: FrameFeatures) -> HeuristicResult:
    level = features.primary_avg

    if features.primary_avg < 0.05:
        usage_text = "좌우 이두근 활성도가 아직 낮습니다."
        usage_tone = "warn"
    elif features.secondary_avg > features.primary_avg * 1.05:
        usage_text = "전완 개입이 더 큽니다. 손목 힘보다 이두 수축에 집중하세요."
        usage_tone = "danger"
    elif features.arm_accel_gap > 0.45:
        usage_text = "좌우 팔의 컬 범위가 다릅니다. 한쪽만 더 높게 들리지 않는지 확인하세요."
        usage_tone = "warn"
    elif features.primary_gap > 0.16:
        usage_text = "좌우 이두 사용 차이가 큽니다."
        usage_tone = "warn"
    else:
        usage_text = "이두근 중심 사용이 양호합니다."
        usage_tone = "good"

    if features.torso_motion > 8.0:
        pose = ("Control", "몸통 반동 주의", "몸통을 고정하고 팔꿈치를 축으로 컬 동작을 유지하세요.", "danger")
    elif features.arm_accel_gap > 0.45:
        pose = ("Balance", "좌우 컬 높이 차이", "양팔이 시작 자세 대비 비슷한 범위로 접히는지 확인하세요.", "warn")
    elif features.arm_motion_gap > 6.0:
        pose = ("Balance", "좌우 컬 속도 차이", "양팔 컬 속도와 리듬을 맞춰보세요.", "warn")
    elif not features.motion_detected and features.primary_avg > 0.08:
        pose = ("Range", "수축 유지 중", "정점 수축은 좋습니다. 천천히 내려오며 장력을 유지하세요.", "good")
    else:
        pose = ("Posture", "컬 자세 양호", "팔꿈치 고정과 이두 수축이 안정적입니다.", "good")

    return HeuristicResult(
        activation_percent=int(round(_clamp01(level) * 100.0)),
        channel_activation_percent=_channel_activation_percent(features),
        activation_level=_activation_level(level),
        usage_text=usage_text,
        usage_tone=usage_tone,
        pose_badge=pose[0],
        pose_title=pose[1],
        pose_detail=pose[2],
        pose_tone=pose[3],
    )


def _analyze_lateral_raise(features: FrameFeatures) -> HeuristicResult:
    level = features.primary_avg

    if features.primary_avg < 0.05:
        usage_text = "좌우 측면 삼각근 활성도가 아직 낮습니다."
        usage_tone = "warn"
    elif features.secondary_avg > features.primary_avg * 0.90:
        usage_text = "승모근 보상이 큽니다. 어깨를 끌어올리지 않도록 주의하세요."
        usage_tone = "danger"
    elif features.arm_accel_gap > 0.35:
        usage_text = "좌우 팔이 시작 자세 대비 다른 높이로 올라가고 있습니다."
        usage_tone = "warn"
    elif features.primary_gap > 0.16:
        usage_text = "좌우 삼각근 사용 차이가 큽니다."
        usage_tone = "warn"
    else:
        usage_text = "삼각근 중심 사용이 안정적입니다."
        usage_tone = "good"

    if features.torso_motion > 8.0:
        pose = ("Tempo", "몸통 반동 감지", "몸통 반동을 줄이고 팔을 부드럽게 들어 올리세요.", "danger")
    elif features.arm_accel_gap > 0.35:
        pose = ("Balance", "좌우 리프팅 높이 차이", "양팔이 시작 자세 대비 같은 각도로 올라가는지 확인하세요.", "warn")
    elif features.arm_motion_gap > 5.0:
        pose = ("Balance", "좌우 높이 차이 주의", "양팔이 같은 속도와 각도로 올라가는지 확인하세요.", "warn")
    elif features.secondary_gap > 0.14:
        pose = ("Control", "좌우 승모 보상 차이", "한쪽 어깨만 먼저 들리지 않도록 조정하세요.", "warn")
    else:
        pose = ("Posture", "어깨 라인 양호", "측면 삼각근 위주로 안정적으로 수행 중입니다.", "good")

    return HeuristicResult(
        activation_percent=int(round(_clamp01(level) * 100.0)),
        channel_activation_percent=_channel_activation_percent(features),
        activation_level=_activation_level(level),
        usage_text=usage_text,
        usage_tone=usage_tone,
        pose_badge=pose[0],
        pose_title=pose[1],
        pose_detail=pose[2],
        pose_tone=pose[3],
    )


def analyze_frame(
    exercise_type: Optional[str],
    frame: Optional[DecodedFrame],
    calibration: Optional[Any] = None,
) -> HeuristicResult:
    if not exercise_type or frame is None:
        return build_waiting_result()

    features = _extract_features(frame, calibration)

    if _should_block_for_detached_channels(features):
        detached_channels = ", ".join(
            f"EMG {index}" for index in _detached_channel_indices(features)
        )
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=_channel_activation_percent(features),
            activation_level="LOW",
            usage_text="핵심 EMG 채널이 분리되어 근활성도 값을 신뢰하기 어렵습니다.",
            usage_tone="danger",
            pose_badge="Sensor",
            pose_title="센서 재부착 필요",
            pose_detail=(
                f"{detached_channels} 값이 1.000으로 감지되었습니다. "
                "전극 부착 상태를 먼저 확인한 뒤 다시 진행해주세요."
            ),
            pose_tone="danger",
        )

    if exercise_type == "pushup":
        result = _analyze_pushup(features)
    elif exercise_type == "lateral_raise":
        result = _analyze_lateral_raise(features)
    else:
        result = _analyze_bicep_curl(features)

    if features.detached_emg_channels > 0:
        return _apply_partial_detached_warning(result, features)
    return result

    if features.detached_emg_channels > 0:
        return HeuristicResult(
            activation_percent=0,
            channel_activation_percent=_channel_activation_percent(features),
            activation_level="LOW",
            usage_text="EMG 센서 일부가 분리되어 근활성 값을 신뢰할 수 없습니다.",
            usage_tone="danger",
            pose_badge="Sensor",
            pose_title="센서 재부착 필요",
            pose_detail="EMG 값이 1.000에 가까운 채널이 있습니다. 전극 부착 상태를 먼저 확인하세요.",
            pose_tone="danger",
        )

    if exercise_type == "pushup":
        return _analyze_pushup(features)
    if exercise_type == "lateral_raise":
        return _analyze_lateral_raise(features)
    return _analyze_bicep_curl(features)


def build_emg_channel_activations(
    exercise_type: Optional[str],
    frame: Optional[DecodedFrame],
    calibration: Optional[Any] = None,
) -> list[dict[str, Any]]:
    if frame is None:
        return [
            {
                "index": index + 1,
                "name": f"EMG {index + 1}",
                "muscle": "",
                "attached": False,
                "activation_percent": 0,
                "activation_level": "LOW",
                "raw_value": 0.0,
            }
            for index in range(4)
        ]

    features = _extract_features(frame, calibration)
    labels = SENSOR_CONFIGS.get(exercise_type or "", [])
    values = [
        features.left_primary,
        features.right_primary,
        features.left_secondary,
        features.right_secondary,
    ]

    channels: list[dict[str, Any]] = []
    for index, value in enumerate(values):
        default_name = f"EMG {index + 1}"
        label_name, label_muscle = (
            labels[index] if index < len(labels) else (default_name, "")
        )
        raw_value = frame.emg[index] if index < len(frame.emg) else 0.0
        attached = raw_value < EMG_DETACHED_THRESHOLD
        channels.append(
            {
                "index": index + 1,
                "name": label_name,
                "muscle": label_muscle,
                "attached": attached,
                "activation_percent": int(round(_clamp01(value) * 100.0))
                if attached
                else 0,
                "activation_level": _activation_level(value) if attached else "LOW",
                "raw_value": round(raw_value, 4),
            }
        )
    return channels
