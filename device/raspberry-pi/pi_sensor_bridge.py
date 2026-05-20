#!/usr/bin/env python3
"""Bridge ESP32 serial frames to app-facing WebSocket messages and glass UI."""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import threading
import time
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Optional

try:
    import serial
except ModuleNotFoundError as exc:
    raise SystemExit(
        "pyserial이 필요합니다. `pip install pyserial` 후 다시 실행하세요."
    ) from exc

try:
    from websockets.asyncio.server import ServerConnection, serve
except ModuleNotFoundError as exc:
    raise SystemExit(
        "websockets 패키지가 필요합니다. `pip install websockets` 후 다시 실행하세요."
    ) from exc

from esp32_serial_receiver import (
    FRAME_SIZE,
    MAGIC,
    STATE_NAMES,
    DecodedFrame,
    decode_frame,
)
from glass_metrics import (
    SENSOR_CONFIGS,
    analyze_frame,
    build_emg_channel_activations,
    build_phase_result,
    build_waiting_result,
)


UI_DIR = Path(__file__).with_name("glass-ui")
EMG_DETACHED_THRESHOLD = 0.99
# ESP32 sample rate = 50Hz (kSampleIntervalMs=20). 따라서 프레임 수 / 50 = 측정 초.
# 운동 앱 캘리브레이션 전용 기준. 게임 페이지는 별도 로직을 사용하므로 이 값에 영향받지 않는다.
CALIBRATION_REST_FRAMES = 250   # 5.0s @ 50Hz
CALIBRATION_MVC_FRAMES = 250    # 5.0s @ 50Hz
CALIBRATION_TIMEOUT_SEC = 20.0
PRESET_CALIBRATION_STAGE_SEC = 5.0
# 2026-05-12 17:52:49 bicep_curl 로그 기준. 센서 실측 없이 데모 플로우를
# 통과시킬 때만 사용하며, 기본 실행에서는 비활성화한다.
PRESET_CALIBRATION_REST_BASELINE = [0.0079, 0.0105, 0.0, 0.0039]
PRESET_CALIBRATION_MVC = [0.9, 0.9, 0.707, 0.899]
CALIBRATION_MIN_VALID_EMG_FRAMES = 10
CALIBRATION_REST_MAX_EMG_MEAN = 0.12
CALIBRATION_REST_MAX_EMG_STD = 0.05
CALIBRATION_REST_MAX_GYRO_NORM = 8.0
CALIBRATION_MVC_MIN_VALID_RATIO = 0.70
CALIBRATION_MVC_NOISE_MULTIPLIER = 3.0
CALIBRATION_MVC_ACTIVE_DELTA_FLOOR = 0.015
CALIBRATION_MVC_MIN_PRIMARY_DELTA = 0.03
CALIBRATION_MVC_MIN_SECONDARY_DELTA = 0.012
CALIBRATION_MVC_MIN_PRIMARY_PEAK_DELTA = 0.05
CALIBRATION_MVC_MIN_SECONDARY_PEAK_DELTA = 0.03
CALIBRATION_MVC_MIN_PRIMARY_ACTIVE_FRAMES = 10
CALIBRATION_MVC_MIN_SECONDARY_ACTIVE_FRAMES = 4
CALIBRATION_MVC_MIN_PRIMARY_SYNC_FRAMES = 6
EXERCISE_LABELS = {
    "pushup": "Push-up",
    "bicep_curl": "Bicep Curl",
    "lateral_raise": "Lateral Raise",
}


@dataclass(frozen=True)
class ConnectionSnapshot:
    pi_connected: bool
    esp32_connected: bool
    glass_connected: bool


@dataclass(frozen=True)
class SessionSnapshot:
    exercise_type: Optional[str]
    exercise_label: str
    phase: str
    phase_label: str
    set_count: int
    current_set_index: int
    target_reps_per_set: list[int]
    target_rep: Optional[int]
    rest_sec: int
    rest_remaining_sec: int
    current_rep: Optional[int]
    current_speed_label: str
    sensors_attached: bool


@dataclass
class CalibrationData:
    exercise_type: Optional[str] = None
    emg_rest_baseline: list[float] = field(default_factory=lambda: [0.0] * 4)
    emg_mvc: list[float] = field(default_factory=lambda: [1.0] * 4)
    emg_activation_threshold: list[float] = field(default_factory=lambda: [0.05] * 4)
    imu_rest_accel: list[list[float]] = field(
        default_factory=lambda: [[0.0, 0.0, 0.0] for _ in range(3)]
    )
    imu_rest_gyro: list[list[float]] = field(
        default_factory=lambda: [[0.0, 0.0, 0.0] for _ in range(3)]
    )
    ready: bool = False


@dataclass
class SetSummary:
    set_index: int
    target_reps: int
    actual_reps: int
    compensation_count: int
    avg_speed: str
    started_at: str
    ended_at: str


@dataclass
class SessionAccumulator:
    session_id: Optional[str] = None
    started_at: Optional[str] = None
    ended_at: Optional[str] = None
    status: str = "completed"
    end_reason: str = "auto_completed"
    current_set_started_at: Optional[str] = None
    normalized_sums: list[float] = field(default_factory=lambda: [0.0] * 4)
    normalized_counts: list[int] = field(default_factory=lambda: [0] * 4)
    actual_reps_per_set: list[int] = field(default_factory=list)
    set_results: list[SetSummary] = field(default_factory=list)
    valid_rep_count: int = 0
    active_frame_count: int = 0


@dataclass
class RepCounterState:
    phase: str = "ready"
    phase_started_ts_ms: Optional[int] = None
    peak_score: float = 0.0
    previous_score: float = 0.0
    below_start_frames: int = 0
    return_frames: int = 0


@dataclass(frozen=True)
class RepMotionProfile:
    score: float
    primary_activation: float
    secondary_activation: float
    left_primary: float
    right_primary: float
    left_accel: float
    right_accel: float
    torso_accel: float
    left_gyro: float
    right_gyro: float
    torso_gyro: float
    arm_accel_avg: float
    arm_accel_min: float
    arm_gyro_avg: float
    arm_gyro_max: float
    symmetry_gap: float
    motion_detected: bool


class BridgeState:
    def __init__(self, rep_debug: bool = False, preset_calibration: bool = False) -> None:
        self._lock = threading.Lock()
        self._esp32_connected = False
        self._glass_connected = False
        self._preset_calibration = preset_calibration
        self._exercise_type: Optional[str] = None
        self._phase = "idle"
        self._set_count = 0
        self._target_reps_per_set: list[int] = []
        self._rest_sec = 0
        self._current_rep: Optional[int] = None
        self._current_set_index = 0
        self._rest_deadline_monotonic: Optional[float] = None
        self._paused_phase: Optional[str] = None
        self._paused_rest_remaining_sec = 0
        self._sensors_attached = False
        self._motion_active = False
        self._last_rep_timestamp_ms: Optional[int] = None
        self._current_set_rep_intervals_ms: list[int] = []
        self._last_rep_speed_label = "분석 중"
        self._rep_counter = RepCounterState()
        self._rep_debug = rep_debug
        self._last_rep_debug_timestamp_ms: Optional[int] = None
        self._ignored_device_rep_index_logged = False
        self._calibration_data = CalibrationData()
        self._calibration_rest_std = [0.0] * 4
        self._calibration_frames: list[DecodedFrame] = []
        self._calibration_collecting = False
        self._calibration_stage = "idle"
        self._calibration_started_monotonic: Optional[float] = None
        self._calibration_failure_message: Optional[str] = None
        self._calibration_last_rejection_reason: Optional[str] = None
        self._calibration_rejection_streak = 0
        self._session_accumulator = SessionAccumulator()
        self._pending_session_result: Optional[dict[str, Any]] = None

    def update_frame(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        with self._lock:
            events: list[dict[str, Any]] = []
            self._esp32_connected = True
            if self._phase == "calibrating" and not self._calibration_collecting:
                # calibrating 상태에서 collection 이 꺼졌다는 건 캘리브레이션이 끝났다는 의미.
                # 앱의 start_workout 입력 전까지 monitoring 으로 자동 진입하지 않도록 대기 상태로 보낸다.
                print(
                    "[calib] WARN update_frame found phase=calibrating but collecting=False"
                    " — falling back to awaiting_workout_start"
                )
                self._phase = "awaiting_workout_start"
            if frame.rep_index is not None and not self._ignored_device_rep_index_logged:
                self._ignored_device_rep_index_logged = True
                self._log_rep_debug_locked(
                    f"device rep_index={frame.rep_index} observed but ignored; Pi-side exercise counter is active"
                )
            events.extend(self._maybe_finish_rest_locked())
            events.extend(self._maybe_increment_rep(frame))
            return events

    def tick(self) -> list[dict[str, Any]]:
        with self._lock:
            return self._maybe_finish_rest_locked()

    def advance_preset_calibration(self) -> Optional[str]:
        with self._lock:
            if not self._preset_calibration:
                return None
            if self._calibration_started_monotonic is None:
                return None
            if time.monotonic() - self._calibration_started_monotonic < PRESET_CALIBRATION_STAGE_SEC:
                return None

            if self._calibration_stage == "preset_rest":
                self._apply_preset_rest_calibration_locked()
                self._calibration_stage = "preset_mvc"
                self._phase = "calibrating_mvc"
                self._calibration_started_monotonic = time.monotonic()
                print("[calib] preset rest injected — switching to MVC stage")
                return "rest_complete"

            if self._calibration_stage == "preset_mvc":
                self._apply_preset_mvc_calibration_locked()
                self._calibration_started_monotonic = None
                self._phase = "awaiting_workout_start"
                self._start_workout_locked()
                print("[calib] preset mvc injected — calibration success")
                return "mvc_complete"

            return None

    def check_calibration_timeout(self) -> bool:
        # 프레임 수신이 멈춰서 maybe_collect_calibration_frame 자체가 호출되지 않을 때도
        # 타임아웃이 발화되도록 별도 진입점에서 검사한다.
        with self._lock:
            if not self._calibration_collecting:
                return False
            if self._calibration_started_monotonic is None:
                return False
            if time.monotonic() - self._calibration_started_monotonic <= CALIBRATION_TIMEOUT_SEC:
                return False
            stage = self._calibration_stage
            frame_count = len(self._calibration_frames)
            reason_suffix = ""
            if frame_count == 0 and self._calibration_last_rejection_reason:
                reason_suffix = f" (last rejection: {self._calibration_last_rejection_reason})"
            print(
                f"[calib] timeout fired stage={stage} collected={frame_count} "
                f"(no frames advancing for >{CALIBRATION_TIMEOUT_SEC:.0f}s){reason_suffix}"
            )
            self._fail_calibration_locked(
                "캘리브레이션 제한 시간을 초과했습니다. 센서를 다시 확인하고 재시도하세요."
            )
            return True

    def set_glass_connected(self, connected: bool) -> None:
        with self._lock:
            self._glass_connected = connected

    def set_workout_plan(
        self,
        exercise_type: str,
        set_count: int,
        target_reps_per_set: list[int],
        rest_sec: int,
    ) -> None:
        with self._lock:
            self._exercise_type = exercise_type
            self._set_count = set_count
            self._target_reps_per_set = target_reps_per_set
            self._rest_sec = rest_sec
            self._current_rep = None
            self._current_set_index = 0
            self._rest_deadline_monotonic = None
            self._paused_phase = None
            self._paused_rest_remaining_sec = 0
            self._phase = "ready_for_calibration"
            self._sensors_attached = False
            self._motion_active = False
            self._last_rep_timestamp_ms = None
            self._current_set_rep_intervals_ms = []
            self._last_rep_speed_label = "분석 중"
            self._reset_rep_counter_locked()
            self._last_rep_debug_timestamp_ms = None
            self._ignored_device_rep_index_logged = False
            self._reset_calibration_results_locked(exercise_type=exercise_type)
            self._calibration_frames = []
            self._calibration_collecting = False
            self._calibration_stage = "idle"
            self._calibration_started_monotonic = None
            self._calibration_failure_message = None
            self._session_accumulator = SessionAccumulator(
                session_id=f"sess_{uuid.uuid4().hex[:12]}",
                actual_reps_per_set=[0] * set_count,
            )
            self._pending_session_result = None

    def mark_sensors_attached(self) -> None:
        with self._lock:
            self._sensors_attached = True
            if self._phase == "ready_for_calibration":
                self._phase = "sensors_ready"

    def start_calibration_collection(self) -> None:
        with self._lock:
            self._reset_calibration_results_locked()
            self._calibration_frames = []
            self._calibration_collecting = not self._preset_calibration
            self._calibration_stage = "preset_rest" if self._preset_calibration else "rest"
            self._phase = "calibrating"
            self._calibration_started_monotonic = time.monotonic()
            self._calibration_failure_message = None
            self._calibration_last_rejection_reason = None
            self._calibration_rejection_streak = 0
            if self._preset_calibration:
                print(
                    "[calib] preset start stage=rest "
                    f"wait={PRESET_CALIBRATION_STAGE_SEC:.0f}s"
                )
                return
            print(
                f"[calib] start stage=rest need_frames={CALIBRATION_REST_FRAMES} "
                f"timeout={CALIBRATION_TIMEOUT_SEC:.0f}s"
            )

    def mark_paused(self) -> None:
        with self._lock:
            if self._phase == "paused":
                return
            self._paused_phase = self._phase
            if self._phase == "resting" and self._rest_deadline_monotonic is not None:
                remaining = self._rest_deadline_monotonic - time.monotonic()
                self._paused_rest_remaining_sec = max(0, math.ceil(remaining))
                self._rest_deadline_monotonic = None
            self._phase = "paused"

    def mark_monitoring(self) -> None:
        with self._lock:
            if self._phase == "paused":
                resume_phase = self._paused_phase or "monitoring"
                if resume_phase == "resting":
                    self._rest_deadline_monotonic = time.monotonic() + self._paused_rest_remaining_sec
                self._phase = resume_phase
                self._paused_phase = None
                self._paused_rest_remaining_sec = 0
                return
            self._phase = "monitoring"

    def start_workout(self) -> bool:
        # 앱의 start_workout 요청을 받아 monitoring 으로 진입하고 세션 시작 시각을 기록.
        # awaiting_workout_start 가 아닌 다른 phase 에서 호출되면 무시한다.
        with self._lock:
            if self._phase == "monitoring":
                return True
            if self._phase != "awaiting_workout_start":
                return False
            self._start_workout_locked()
            return True

    def _start_workout_locked(self) -> None:
        # calibration/대기 화면에서도 sensor frame 은 계속 들어오므로 rep_index,
        # motion state, 속도 측정 시점이 남아 있을 수 있다. 이를 비우지 않으면
        # 실제 운동 첫 반복이 누락되거나 이전 상태를 이어받아 오검출된다.
        self._current_rep = None
        self._motion_active = False
        self._last_rep_timestamp_ms = None
        self._current_set_rep_intervals_ms = []
        self._last_rep_speed_label = "분석 중"
        self._reset_rep_counter_locked()
        self._last_rep_debug_timestamp_ms = None
        self._ignored_device_rep_index_logged = False
        self._phase = "monitoring"
        self._ensure_session_started_locked()

    def mark_completed(self) -> None:
        with self._lock:
            self._phase = "completed"
            self._rest_deadline_monotonic = None
            if self._session_accumulator.ended_at is None:
                self._session_accumulator.ended_at = now_iso()

    def mark_esp32_disconnected(self) -> None:
        with self._lock:
            self._esp32_connected = False

    def connection_snapshot(self) -> ConnectionSnapshot:
        with self._lock:
            return ConnectionSnapshot(
                pi_connected=True,
                esp32_connected=self._esp32_connected,
                glass_connected=self._glass_connected,
            )

    def session_snapshot(self) -> SessionSnapshot:
        with self._lock:
            return SessionSnapshot(
                exercise_type=self._exercise_type,
                exercise_label=EXERCISE_LABELS.get(self._exercise_type, "Waiting"),
                phase=self._phase,
                phase_label=self._phase_label(self._phase),
                set_count=self._set_count,
                current_set_index=self._current_set_index + 1 if self._set_count > 0 else 0,
                target_reps_per_set=list(self._target_reps_per_set),
                target_rep=self._current_target_rep_locked(),
                rest_sec=self._rest_sec,
                rest_remaining_sec=self._rest_remaining_sec_locked(),
                current_rep=self._current_rep,
                current_speed_label=self._last_rep_speed_label,
                sensors_attached=self._sensors_attached,
            )

    def calibration_snapshot(self) -> CalibrationData:
        with self._lock:
            return CalibrationData(
                exercise_type=self._calibration_data.exercise_type,
                emg_rest_baseline=list(self._calibration_data.emg_rest_baseline),
                emg_mvc=list(self._calibration_data.emg_mvc),
                emg_activation_threshold=list(self._calibration_data.emg_activation_threshold),
                imu_rest_accel=[list(v) for v in self._calibration_data.imu_rest_accel],
                imu_rest_gyro=[list(v) for v in self._calibration_data.imu_rest_gyro],
                ready=self._calibration_data.ready,
            )

    def calibration_progress_snapshot(self) -> float:
        with self._lock:
            return self._calibration_progress_locked()

    def consume_calibration_failure_message(self) -> Optional[str]:
        with self._lock:
            message = self._calibration_failure_message
            self._calibration_failure_message = None
            return message

    def consume_pending_session_result(self) -> Optional[dict[str, Any]]:
        with self._lock:
            payload = self._pending_session_result
            self._pending_session_result = None
            return payload

    def finalize_session(self, status: str, end_reason: str) -> None:
        with self._lock:
            self._finalize_session_locked(status, end_reason)

    def _reset_calibration_results_locked(
        self,
        exercise_type: Optional[str] = None,
    ) -> None:
        resolved_exercise = (
            exercise_type
            or self._exercise_type
            or self._calibration_data.exercise_type
        )
        self._calibration_data = CalibrationData(exercise_type=resolved_exercise)
        self._calibration_rest_std = [0.0] * 4

    def _calibration_progress_locked(self) -> float:
        if self._calibration_data.ready or self._calibration_stage == "done":
            return 1.0
        if self._calibration_stage == "preset_mvc":
            elapsed = (
                0.0
                if self._calibration_started_monotonic is None
                else time.monotonic() - self._calibration_started_monotonic
            )
            return 0.5 + min(0.5, elapsed / PRESET_CALIBRATION_STAGE_SEC * 0.5)
        if self._calibration_stage == "preset_rest":
            elapsed = (
                0.0
                if self._calibration_started_monotonic is None
                else time.monotonic() - self._calibration_started_monotonic
            )
            return min(0.5, elapsed / PRESET_CALIBRATION_STAGE_SEC * 0.5)
        if self._calibration_stage == "mvc":
            return 0.5 + min(0.5, len(self._calibration_frames) / CALIBRATION_MVC_FRAMES * 0.5)
        if self._calibration_stage == "rest":
            return min(0.5, len(self._calibration_frames) / CALIBRATION_REST_FRAMES * 0.5)
        return 0.0

    def _apply_preset_rest_calibration_locked(self) -> None:
        self._calibration_data.emg_rest_baseline = list(PRESET_CALIBRATION_REST_BASELINE)
        self._calibration_data.emg_activation_threshold = [
            baseline + 0.03 for baseline in self._calibration_data.emg_rest_baseline
        ]
        self._calibration_data.imu_rest_accel = [[0.0, 0.0, 0.0] for _ in range(3)]
        self._calibration_data.imu_rest_gyro = [[0.0, 0.0, 0.0] for _ in range(3)]
        self._calibration_rest_std = [0.0] * 4
        self._calibration_data.ready = False

    def _apply_preset_mvc_calibration_locked(self) -> None:
        self._calibration_data.emg_mvc = [
            max(PRESET_CALIBRATION_MVC[index], self._calibration_data.emg_rest_baseline[index] + 0.05)
            for index in range(4)
        ]
        self._calibration_data.ready = True
        self._calibration_collecting = False
        self._calibration_frames = []
        self._calibration_stage = "done"
        self._calibration_failure_message = None

    def _valid_emg_values(self, frame: DecodedFrame) -> list[Optional[float]]:
        values: list[Optional[float]] = []
        for value in frame.emg:
            values.append(None if value >= EMG_DETACHED_THRESHOLD else value)
        return values

    @staticmethod
    def _detached_channels(frame: DecodedFrame) -> list[int]:
        return [
            index
            for index, value in enumerate(frame.emg)
            if value >= EMG_DETACHED_THRESHOLD
        ]

    @staticmethod
    def _imu_gyro_norms(frame: DecodedFrame) -> list[float]:
        norms: list[float] = []
        for imu_gyro in frame.imu_gyros[:3]:
            norms.append(sum(abs(axis) for axis in imu_gyro))
        return norms

    def _rest_frame_rejection_reason_locked(
        self,
        frame: DecodedFrame,
    ) -> Optional[str]:
        # REST 단계에서는 프레임 수집 자체를 막지 않고, 수집 후 baseline/noise/
        # 유효 샘플 수를 한 번에 검증한다. 프레임 단계에서 탈락시키면 collected=0
        # 타임아웃만 남아서 실제 실패 사유가 가려질 수 있다.
        return None

    def _reset_rest_window_locked(self, reason: str) -> None:
        if reason == self._calibration_last_rejection_reason:
            self._calibration_rejection_streak += 1
        else:
            self._calibration_last_rejection_reason = reason
            self._calibration_rejection_streak = 1
        if self._calibration_rejection_streak == 1 or self._calibration_rejection_streak % 50 == 0:
            print(
                f"[calib] rest frame rejected reason={reason} "
                f"streak={self._calibration_rejection_streak}"
            )
        if not self._calibration_frames:
            return
        print(
            f"[calib] rest window reset accepted={len(self._calibration_frames)} "
            f"reason={reason}"
        )
        self._calibration_frames = []

    def _normalized_emg_values_locked(self, frame: DecodedFrame) -> list[float]:
        valid_emg = self._valid_emg_values(frame)
        normalized = [0.0] * 4
        for index, value in enumerate(valid_emg):
            if value is None:
                continue
            baseline = self._calibration_data.emg_rest_baseline[index]
            mvc = self._calibration_data.emg_mvc[index]
            denominator = max(mvc - baseline, 1e-6)
            normalized[index] = max(0.0, min(1.0, (value - baseline) / denominator))
        return normalized

    def _max_accel_delta_locked(self, frame: DecodedFrame) -> float:
        accel_delta = 0.0
        for imu_index, imu_accel in enumerate(frame.imu_accels[:3]):
            baseline = self._calibration_data.imu_rest_accel[imu_index]
            accel_delta = max(
                accel_delta,
                abs(imu_accel[0] - baseline[0])
                + abs(imu_accel[1] - baseline[1])
                + abs(imu_accel[2] - baseline[2]),
            )
        return accel_delta

    def _gyro_delta_locked(self, frame: DecodedFrame) -> float:
        imu_gyro = frame.imu_gyros[0] if frame.imu_gyros else (0.0, 0.0, 0.0)
        gyro_baseline = self._calibration_data.imu_rest_gyro[0]
        return (
            math.fabs(imu_gyro[0] - gyro_baseline[0])
            + math.fabs(imu_gyro[1] - gyro_baseline[1])
            + math.fabs(imu_gyro[2] - gyro_baseline[2])
        )

    def _imu_accel_deltas_locked(self, frame: DecodedFrame) -> list[float]:
        deltas = [0.0, 0.0, 0.0]
        for imu_index, imu_accel in enumerate(frame.imu_accels[:3]):
            baseline = self._calibration_data.imu_rest_accel[imu_index]
            deltas[imu_index] = (
                abs(imu_accel[0] - baseline[0])
                + abs(imu_accel[1] - baseline[1])
                + abs(imu_accel[2] - baseline[2])
            )
        return deltas

    def _imu_gyro_deltas_locked(self, frame: DecodedFrame) -> list[float]:
        deltas = [0.0, 0.0, 0.0]
        for imu_index, imu_gyro in enumerate(frame.imu_gyros[:3]):
            baseline = self._calibration_data.imu_rest_gyro[imu_index]
            deltas[imu_index] = (
                abs(imu_gyro[0] - baseline[0])
                + abs(imu_gyro[1] - baseline[1])
                + abs(imu_gyro[2] - baseline[2])
            )
        return deltas

    def _build_rep_motion_profile_locked(self, frame: DecodedFrame) -> RepMotionProfile:
        normalized = self._normalized_emg_values_locked(frame)
        accel_deltas = self._imu_accel_deltas_locked(frame)
        gyro_deltas = self._imu_gyro_deltas_locked(frame)

        left_primary = normalized[0]
        right_primary = normalized[1]
        left_secondary = normalized[2]
        right_secondary = normalized[3]
        primary_activation = (left_primary + right_primary) / 2.0
        secondary_activation = (left_secondary + right_secondary) / 2.0
        arm_accel_avg = (accel_deltas[0] + accel_deltas[1]) / 2.0
        arm_accel_min = min(accel_deltas[0], accel_deltas[1])
        arm_gyro_avg = (gyro_deltas[0] + gyro_deltas[1]) / 2.0
        arm_gyro_max = max(gyro_deltas[0], gyro_deltas[1])
        symmetry_gap = abs(accel_deltas[0] - accel_deltas[1]) + 0.12 * abs(gyro_deltas[0] - gyro_deltas[1])

        if self._exercise_type == "pushup":
            score = (
                arm_accel_avg
                + 0.010 * arm_gyro_avg
                + 0.35 * primary_activation
                + 0.18 * secondary_activation
            )
        elif self._exercise_type == "lateral_raise":
            score = (
                arm_accel_avg
                + 0.012 * arm_gyro_avg
                + 0.42 * primary_activation
                + 0.12 * secondary_activation
            )
        else:
            score = (
                arm_accel_avg
                + 0.014 * arm_gyro_avg
                + 0.45 * primary_activation
                + 0.14 * secondary_activation
            )

        return RepMotionProfile(
            score=score,
            primary_activation=primary_activation,
            secondary_activation=secondary_activation,
            left_primary=left_primary,
            right_primary=right_primary,
            left_accel=accel_deltas[0],
            right_accel=accel_deltas[1],
            torso_accel=accel_deltas[2],
            left_gyro=gyro_deltas[0],
            right_gyro=gyro_deltas[1],
            torso_gyro=gyro_deltas[2],
            arm_accel_avg=arm_accel_avg,
            arm_accel_min=arm_accel_min,
            arm_gyro_avg=arm_gyro_avg,
            arm_gyro_max=arm_gyro_max,
            symmetry_gap=symmetry_gap,
            motion_detected=bool(frame.flags & 0x04),
        )

    def _min_rep_gap_ms_locked(self) -> int:
        if self._exercise_type == "pushup":
            return 850
        if self._exercise_type == "lateral_raise":
            return 800
        return 700

    def _start_rep_condition_locked(self, profile: RepMotionProfile) -> bool:
        if self._exercise_type == "pushup":
            has_motion = (
                profile.motion_detected
                or profile.arm_gyro_avg >= 1.2
                or profile.arm_accel_avg >= 0.16
            )
            return (
                profile.score >= 0.26
                and profile.arm_accel_min >= 0.10
                and profile.primary_activation >= 0.04
                and min(profile.left_primary, profile.right_primary) >= 0.02
                and has_motion
            )
        if self._exercise_type == "lateral_raise":
            has_motion = (
                profile.motion_detected
                or profile.arm_gyro_avg >= 1.0
                or profile.arm_accel_avg >= 0.14
            )
            return (
                profile.score >= 0.24
                and profile.arm_accel_min >= 0.09
                and profile.primary_activation >= 0.05
                and min(profile.left_primary, profile.right_primary) >= 0.025
                and has_motion
            )
        # bicep curl 은 실기에서 좌/우가 완전히 대칭으로 들어오지 않는 경우가 많다.
        # 특히 한쪽 팔 IMU/EMG 가 더 강하게 반응해도 유효한 컬 동작일 수 있으므로
        # 좌/우 평균/최소값 대신 "더 강하게 반응한 팔" 기준으로 시작을 판정한다.
        dominant_primary = max(profile.left_primary, profile.right_primary)
        dominant_accel = max(profile.left_accel, profile.right_accel)
        dominant_gyro = max(profile.left_gyro, profile.right_gyro)
        has_motion = (
            (profile.motion_detected and dominant_accel >= 0.08)
            or dominant_gyro >= 2.5
            or dominant_accel >= 0.12
        )
        return (
            dominant_primary >= 0.06
            and dominant_accel >= 0.10
            and (profile.score >= 0.14 or dominant_gyro >= 3.0)
            and has_motion
        )

    def _peak_rep_condition_locked(self, profile: RepMotionProfile) -> bool:
        if self._exercise_type == "pushup":
            return (
                profile.score >= 0.58
                and profile.arm_accel_min >= 0.22
                and profile.primary_activation >= 0.11
            )
        if self._exercise_type == "lateral_raise":
            return (
                profile.score >= 0.60
                and profile.arm_accel_min >= 0.26
                and profile.primary_activation >= 0.13
            )
        dominant_primary = max(profile.left_primary, profile.right_primary)
        dominant_accel = max(profile.left_accel, profile.right_accel)
        dominant_gyro = max(profile.left_gyro, profile.right_gyro)
        return (
            dominant_primary >= 0.12
            and dominant_accel >= 0.18
            and (profile.score >= 0.22 or dominant_gyro >= 4.0)
        )

    def _return_rep_condition_locked(self, profile: RepMotionProfile) -> bool:
        if self._exercise_type == "pushup":
            return (
                profile.arm_accel_avg <= 0.16
                and profile.primary_activation <= 0.08
                and profile.arm_gyro_avg <= 1.4
            )
        if self._exercise_type == "lateral_raise":
            return (
                profile.arm_accel_avg <= 0.15
                and profile.primary_activation <= 0.07
                and profile.arm_gyro_avg <= 1.2
            )
        dominant_primary = max(profile.left_primary, profile.right_primary)
        dominant_accel = max(profile.left_accel, profile.right_accel)
        dominant_gyro = max(profile.left_gyro, profile.right_gyro)
        return (
            dominant_accel <= 0.10
            and dominant_primary <= 0.05
            and dominant_gyro <= 1.5
        )

    def _near_rest_rep_condition_locked(self, profile: RepMotionProfile) -> bool:
        if self._exercise_type == "pushup":
            return profile.arm_accel_avg < 0.18 and profile.primary_activation < 0.05
        if self._exercise_type == "lateral_raise":
            return profile.arm_accel_avg < 0.16 and profile.primary_activation < 0.05
        dominant_primary = max(profile.left_primary, profile.right_primary)
        dominant_accel = max(profile.left_accel, profile.right_accel)
        return dominant_accel < 0.12 and dominant_primary < 0.04

    def _reset_rep_counter_locked(self) -> None:
        self._rep_counter = RepCounterState()
        self._motion_active = False

    def _log_rep_debug_locked(self, message: str) -> None:
        if not self._rep_debug:
            return
        exercise = self._exercise_type or "unknown"
        phase = self._rep_counter.phase
        print(f"[rep-debug] ex={exercise} phase={phase} {message}")

    def _maybe_log_rep_profile_locked(
        self,
        frame: DecodedFrame,
        profile: RepMotionProfile,
    ) -> None:
        if not self._rep_debug:
            return
        last_logged = self._last_rep_debug_timestamp_ms
        if last_logged is not None and frame.timestamp_ms - last_logged < 400:
            return
        self._last_rep_debug_timestamp_ms = frame.timestamp_ms
        print(
            "[rep-debug] "
            f"ts={frame.timestamp_ms} ex={self._exercise_type or 'unknown'} "
            f"phase={self._rep_counter.phase} score={profile.score:.3f} "
            f"emg_primary={profile.primary_activation:.3f} "
            f"emg_secondary={profile.secondary_activation:.3f} "
            f"arm_accel_avg={profile.arm_accel_avg:.3f} "
            f"arm_accel_min={profile.arm_accel_min:.3f} "
            f"arm_gyro_avg={profile.arm_gyro_avg:.3f} "
            f"dominant_primary={max(profile.left_primary, profile.right_primary):.3f} "
            f"dominant_accel={max(profile.left_accel, profile.right_accel):.3f} "
            f"dominant_gyro={max(profile.left_gyro, profile.right_gyro):.3f} "
            f"motion={profile.motion_detected}"
        )

    def _ensure_session_started_locked(self) -> None:
        if self._session_accumulator.started_at is None:
            timestamp = now_iso()
            self._session_accumulator.started_at = timestamp
            self._session_accumulator.current_set_started_at = timestamp

    def _current_set_start_locked(self) -> str:
        self._ensure_session_started_locked()
        if self._session_accumulator.current_set_started_at is None:
            self._session_accumulator.current_set_started_at = now_iso()
        return self._session_accumulator.current_set_started_at

    def _track_active_frame_locked(self, frame: DecodedFrame) -> None:
        if not self._calibration_data.ready:
            return
        normalized = self._normalized_emg_values_locked(frame)
        if max(normalized, default=0.0) <= 0.05:
            return
        self._ensure_session_started_locked()
        self._session_accumulator.active_frame_count += 1
        for index, value in enumerate(normalized):
            self._session_accumulator.normalized_sums[index] += value
            self._session_accumulator.normalized_counts[index] += 1

    def _record_set_completion_locked(self, set_index: int, actual_rep: int, target_rep: int) -> None:
        self._ensure_session_started_locked()
        if 0 <= set_index - 1 < len(self._session_accumulator.actual_reps_per_set):
            self._session_accumulator.actual_reps_per_set[set_index - 1] = actual_rep
        started_at = self._current_set_start_locked()
        ended_at = now_iso()
        self._session_accumulator.valid_rep_count += actual_rep
        avg_speed = self._average_speed_label_locked()
        self._session_accumulator.set_results.append(
            SetSummary(
                set_index=set_index,
                target_reps=target_rep,
                actual_reps=actual_rep,
                compensation_count=0,
                avg_speed=avg_speed,
                started_at=started_at,
                ended_at=ended_at,
            )
        )
        self._session_accumulator.current_set_started_at = None
        self._current_set_rep_intervals_ms = []
        self._last_rep_speed_label = "분석 중"

    def _classify_speed_label_locked(self, interval_ms: int) -> str:
        if interval_ms < 900:
            return "빠름"
        if interval_ms < 1800:
            return "적정"
        return "느림"

    def _average_speed_label_locked(self) -> str:
        if not self._current_set_rep_intervals_ms:
            if self._last_rep_speed_label == "분석 중":
                return "normal"
            return {"빠름": "fast", "적정": "normal", "느림": "slow"}.get(
                self._last_rep_speed_label,
                "normal",
            )
        avg_interval = sum(self._current_set_rep_intervals_ms) / len(self._current_set_rep_intervals_ms)
        return {
            "빠름": "fast",
            "적정": "normal",
            "느림": "slow",
        }[self._classify_speed_label_locked(int(avg_interval))]

    def _update_last_rep_speed_locked(self, timestamp_ms: int) -> None:
        if self._last_rep_timestamp_ms is None:
            self._last_rep_speed_label = "분석 중"
            return
        interval_ms = max(0, timestamp_ms - self._last_rep_timestamp_ms)
        if interval_ms <= 0:
            return
        self._current_set_rep_intervals_ms.append(interval_ms)
        self._last_rep_speed_label = self._classify_speed_label_locked(interval_ms)

    def _channel_average_locked(self, index: int) -> float:
        count = self._session_accumulator.normalized_counts[index]
        if count <= 0:
            return 0.0
        return self._session_accumulator.normalized_sums[index] / count

    def _build_muscle_map_locked(self) -> dict[str, float]:
        # 키 명명은 app schema (exercise_muscle_map_schemas) 및
        # docs/pi_muscle_map_alignment.md 와 정합한다.
        # sensor_guide_screen 이 안내하는 부착 위치를 그대로 키로 반영.
        # 스케일 계약: 활성도 값은 0~100 percent. _channel_average_locked 는
        # 0~1 ratio 를 돌려주므로 여기서 *100 변환해서 송신한다.
        ch1 = self._channel_average_locked(0) * 100.0
        ch2 = self._channel_average_locked(1) * 100.0
        ch3 = self._channel_average_locked(2) * 100.0
        ch4 = self._channel_average_locked(3) * 100.0
        if self._exercise_type == "pushup":
            return {
                "left_chest": ch1,
                "right_chest": ch2,
                "left_triceps": ch3,
                "right_triceps": ch4,
            }
        if self._exercise_type == "lateral_raise":
            return {
                "left_lateral_deltoid": ch1,
                "right_lateral_deltoid": ch2,
                "left_upper_trapezius": ch3,
                "right_upper_trapezius": ch4,
            }
        # bicep_curl
        return {
            "left_biceps": ch1,
            "right_biceps": ch2,
            "left_forearm": ch3,
            "right_forearm": ch4,
        }

    def _build_session_result_locked(self, status: str, end_reason: str) -> dict[str, Any]:
        ended_at = now_iso()
        self._session_accumulator.ended_at = ended_at
        self._session_accumulator.status = status
        self._session_accumulator.end_reason = end_reason
        started_at = self._session_accumulator.started_at or ended_at
        total_reps = sum(self._session_accumulator.actual_reps_per_set)
        muscle_map = self._build_muscle_map_locked()
        avg_target = 0.0
        avg_assist = 0.0
        avg_comp = 0.0
        if self._exercise_type == "pushup":
            avg_target = (muscle_map["left_chest"] + muscle_map["right_chest"]) / 2.0
            avg_assist = (muscle_map["left_triceps"] + muscle_map["right_triceps"]) / 2.0
        elif self._exercise_type == "lateral_raise":
            avg_target = (muscle_map["left_lateral_deltoid"] + muscle_map["right_lateral_deltoid"]) / 2.0
            avg_assist = (muscle_map["left_upper_trapezius"] + muscle_map["right_upper_trapezius"]) / 2.0
        elif self._exercise_type == "bicep_curl":
            avg_target = (muscle_map["left_biceps"] + muscle_map["right_biceps"]) / 2.0
            avg_assist = (muscle_map["left_forearm"] + muscle_map["right_forearm"]) / 2.0

        # 좌/우 대흉근이 분리되면서 pushup 도 좌우 밸런스 측정 가능해짐.
        balance_enabled = self._exercise_type in {"pushup", "lateral_raise", "bicep_curl"}
        if self._exercise_type == "pushup":
            left_balance = muscle_map["left_chest"] if balance_enabled else None
            right_balance = muscle_map["right_chest"] if balance_enabled else None
        elif self._exercise_type == "lateral_raise":
            left_balance = muscle_map["left_lateral_deltoid"] if balance_enabled else None
            right_balance = muscle_map["right_lateral_deltoid"] if balance_enabled else None
        elif self._exercise_type == "bicep_curl":
            left_balance = muscle_map["left_biceps"] if balance_enabled else None
            right_balance = muscle_map["right_biceps"] if balance_enabled else None
        else:
            left_balance = None
            right_balance = None
        # 스케일 계약: left/right_balance 는 muscle_map 값이라 이미 0~100 percent.
        # 따라서 threshold 도 percent 단위 (예: 10% 이내 → BALANCED).
        diff_balance = None
        balance_label = None
        if left_balance is not None and right_balance is not None:
            diff_balance = abs(left_balance - right_balance)
            if diff_balance <= 10.0:
                balance_label = "BALANCED"
            elif diff_balance <= 25.0:
                balance_label = "MILD_IMBALANCE"
            else:
                balance_label = "SIGNIFICANT_IMBALANCE"

        payload = {
            "session_id": self._session_accumulator.session_id,
            "exercise_type": self._exercise_type,
            "status": status,
            "end_reason": end_reason,
            "started_at": started_at,
            "ended_at": ended_at,
            "duration_sec": max(0, int((datetime.fromisoformat(ended_at) - datetime.fromisoformat(started_at)).total_seconds())),
            "set_count": self._set_count,
            "target_reps_per_set": list(self._target_reps_per_set),
            "actual_reps_per_set": list(self._session_accumulator.actual_reps_per_set),
            "rest_sec": self._rest_sec,
            "total_reps": total_reps,
            "valid_reps": self._session_accumulator.valid_rep_count,
            "avg_target_muscle": round(avg_target, 4),
            "avg_assist_muscle": round(avg_assist, 4),
            "avg_compensator": round(avg_comp, 4),
            "compensation_count": 0,
            "fatigue_onset_set": None,
            "fatigue_onset_rep": None,
            "comment": "MVC normalized mean activation",
            "calibration_summary": {
                "ch1_mvc": round(self._calibration_data.emg_mvc[0], 4),
                "ch2_mvc": round(self._calibration_data.emg_mvc[1], 4),
                "ch3_mvc": round(self._calibration_data.emg_mvc[2], 4),
                "ch4_mvc": round(self._calibration_data.emg_mvc[3], 4),
            },
            "muscle_map": {key: round(value, 4) for key, value in muscle_map.items()},
            "balance_summary": {
                "enabled": balance_enabled,
                "reason": "left_right_activation_pairing" if balance_enabled else "no_left_right_pairing",
                "left_value": None if left_balance is None else round(left_balance, 4),
                "right_value": None if right_balance is None else round(right_balance, 4),
                "diff_value": None if diff_balance is None else round(diff_balance, 4),
                "balance_label": balance_label,
            },
            "set_results": [asdict(result) for result in self._session_accumulator.set_results],
        }
        return payload

    def _finalize_session_locked(self, status: str, end_reason: str) -> None:
        if self._pending_session_result is not None or self._exercise_type is None:
            return
        self._pending_session_result = wrap_message(
            "session_result",
            self._build_session_result_locked(status, end_reason),
        )

    def _apply_device_rep_index_legacy(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        return []
        events: list[dict[str, Any]] = []
        # ESP32 가 rep_index 를 채워 보내면 update_frame 에서 _maybe_increment_rep
        # 대신 이 함수가 호출된다. _maybe_increment_rep 만 있던 근활성도 누적
        # (_track_active_frame_locked) 을 여기서도 동일하게 수행해야 muscle_map
        # 활성도가 0 으로 머무는 silent failure 를 방지한다.
        if self._phase == "monitoring":
            self._track_active_frame_locked(frame)

        if self._last_device_rep_index is None:
            self._last_device_rep_index = frame.rep_index
            return events

        if frame.rep_index < self._last_device_rep_index:
            # 디바이스 쪽 rep counter 가 리셋/재시작된 경우에는 기준값만 다시 잡고
            # 현재 세트 카운트를 바로 증가시키지 않는다.
            self._last_device_rep_index = frame.rep_index
            return events

        if self._phase != "monitoring":
            self._last_device_rep_index = frame.rep_index
            return events

        delta = frame.rep_index - self._last_device_rep_index
        self._last_device_rep_index = frame.rep_index
        if delta <= 0:
            return events

        self._update_last_rep_speed_locked(frame.timestamp_ms)
        # rep_index 는 mock/문서 기준으로 0-based 누적 카운터이므로, Pi 쪽 state 와
        # 어긋났더라도 절대값에 다시 맞춰준다.
        self._current_rep = frame.rep_index
        self._last_rep_timestamp_ms = frame.timestamp_ms
        return self._maybe_advance_workout_locked(frame.timestamp_ms)

    def _maybe_increment_rep_legacy(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        return []
        if self._phase != "monitoring":
            return []

        normalized_emg = self._normalized_emg_values_locked(frame)
        valid_emg = [value for value in normalized_emg if value > 0.0]
        if not valid_emg:
            self._motion_active = False
            return []

        motion_detected = bool(frame.flags & 0x04)
        primary_emg = max(valid_emg)
        accel_delta = self._max_accel_delta_locked(frame)
        gyro_norm = self._gyro_delta_locked(frame)

        # 실제 장비에서는 rep_index 가 비어 있는 경우가 많아 Pi 추정 경로가 주력이다.
        # calibration 결과에 따라 normalized EMG 가 낮게 나와도, 팔 IMU 움직임이
        # 충분히 크면 카운트가 되도록 조건을 완화한다.
        moderate_motion = motion_detected or accel_delta >= 0.12 or gyro_norm >= 1.4
        strong_motion = accel_delta >= 0.42 or gyro_norm >= 3.4
        active_now = (
            (primary_emg >= 0.08 and moderate_motion)
            or (primary_emg >= 0.04 and strong_motion)
            or strong_motion
        )
        release_now = (
            primary_emg < 0.03
            and not motion_detected
            and accel_delta < 0.08
            and gyro_norm < 0.9
        )

        if active_now:
            self._track_active_frame_locked(frame)

        if active_now and not self._motion_active:
            enough_gap = (
                self._last_rep_timestamp_ms is None
                or frame.timestamp_ms - self._last_rep_timestamp_ms >= 600
            )
            if enough_gap:
                self._update_last_rep_speed_locked(frame.timestamp_ms)
                self._current_rep = 0 if self._current_rep is None else self._current_rep + 1
                self._last_rep_timestamp_ms = frame.timestamp_ms
                self._motion_active = active_now
                return self._maybe_advance_workout_locked(frame.timestamp_ms)

        if self._motion_active and not release_now:
            return []

        self._motion_active = active_now
        return []

    def _maybe_increment_replay_demo_rep(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        normalized_emg = self._normalized_emg_values_locked(frame)
        primary_emg = (normalized_emg[0] + normalized_emg[1]) / 2.0
        active_now = primary_emg >= 0.70
        release_now = primary_emg <= 0.25

        if active_now:
            self._track_active_frame_locked(frame)

        if active_now and not self._motion_active:
            enough_gap = (
                self._last_rep_timestamp_ms is None
                or frame.timestamp_ms - self._last_rep_timestamp_ms >= 1200
            )
            if enough_gap:
                self._motion_active = True
                self._log_rep_debug_locked(
                    f"replay demo rep peak ts={frame.timestamp_ms} primary={primary_emg:.3f}"
                )
            return []

        if self._motion_active and not release_now:
            return []

        if self._motion_active and release_now:
            self._update_last_rep_speed_locked(frame.timestamp_ms)
            self._current_rep = 1 if self._current_rep is None else self._current_rep + 1
            self._last_rep_timestamp_ms = frame.timestamp_ms
            self._motion_active = False
            self._log_rep_debug_locked(
                "replay demo rep counted on release "
                f"ts={frame.timestamp_ms} current_rep={self._current_rep} "
                f"primary={primary_emg:.3f} speed={self._last_rep_speed_label}"
            )
            return self._maybe_advance_workout_locked(frame.timestamp_ms)

        self._motion_active = active_now
        return []

    def _maybe_increment_rep(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        if self._phase != "monitoring":
            self._reset_rep_counter_locked()
            return []

        if self._preset_calibration:
            return self._maybe_increment_replay_demo_rep(frame)

        profile = self._build_rep_motion_profile_locked(frame)
        counter = self._rep_counter
        active_now = (
            counter.phase != "ready"
            or self._start_rep_condition_locked(profile)
            or profile.score >= 0.18
        )
        self._maybe_log_rep_profile_locked(frame, profile)
        if active_now:
            self._track_active_frame_locked(frame)

        if counter.phase == "ready":
            enough_gap = (
                self._last_rep_timestamp_ms is None
                or frame.timestamp_ms - self._last_rep_timestamp_ms >= self._min_rep_gap_ms_locked()
            )
            if enough_gap and self._start_rep_condition_locked(profile):
                self._rep_counter = RepCounterState(
                    phase="driving",
                    phase_started_ts_ms=frame.timestamp_ms,
                    peak_score=profile.score,
                    previous_score=profile.score,
                )
                self._log_rep_debug_locked(
                    "rep start "
                    f"ts={frame.timestamp_ms} score={profile.score:.3f} "
                    f"primary={profile.primary_activation:.3f} "
                    f"arm_accel_avg={profile.arm_accel_avg:.3f} "
                    f"arm_gyro_avg={profile.arm_gyro_avg:.3f}"
                )
                self._motion_active = True
            else:
                self._motion_active = False
            return []

        counter.peak_score = max(counter.peak_score, profile.score)

        if counter.phase == "driving":
            if self._peak_rep_condition_locked(profile):
                counter.phase = "returning"
                counter.return_frames = 0
                self._log_rep_debug_locked(
                    "rep peak "
                    f"ts={frame.timestamp_ms} score={profile.score:.3f} "
                    f"primary={profile.primary_activation:.3f}"
                )
            elif self._near_rest_rep_condition_locked(profile):
                counter.below_start_frames += 1
                if counter.below_start_frames >= 3:
                    self._log_rep_debug_locked(
                        f"rep cancelled near-rest reset ts={frame.timestamp_ms} score={profile.score:.3f}"
                    )
                    self._reset_rep_counter_locked()
                    return []
            else:
                counter.below_start_frames = 0
            counter.previous_score = profile.score
            self._motion_active = True
            return []

        if self._return_rep_condition_locked(profile):
            counter.return_frames += 1
            if counter.return_frames >= 2:
                self._update_last_rep_speed_locked(frame.timestamp_ms)
                self._current_rep = 1 if self._current_rep is None else self._current_rep + 1
                self._last_rep_timestamp_ms = frame.timestamp_ms
                self._log_rep_debug_locked(
                    "rep counted "
                    f"ts={frame.timestamp_ms} current_rep={self._current_rep} "
                    f"score={profile.score:.3f} speed={self._last_rep_speed_label}"
                )
                self._reset_rep_counter_locked()
                return self._maybe_advance_workout_locked(frame.timestamp_ms)
        else:
            counter.return_frames = 0
            if (
                counter.phase_started_ts_ms is not None
                and frame.timestamp_ms - counter.phase_started_ts_ms > 5000
                and self._near_rest_rep_condition_locked(profile)
            ):
                self._log_rep_debug_locked(
                    f"rep timeout reset ts={frame.timestamp_ms} elapsed={frame.timestamp_ms - counter.phase_started_ts_ms}ms"
                )
                self._reset_rep_counter_locked()
                return []

        counter.previous_score = profile.score
        self._motion_active = True
        return []

    def _current_target_rep_locked(self) -> Optional[int]:
        if not self._target_reps_per_set:
            return None
        target_index = min(self._current_set_index, len(self._target_reps_per_set) - 1)
        return self._target_reps_per_set[target_index]

    def _rest_remaining_sec_locked(self) -> int:
        if self._phase == "paused" and self._paused_phase == "resting":
            return self._paused_rest_remaining_sec
        if self._rest_deadline_monotonic is None:
            return 0
        return max(0, math.ceil(self._rest_deadline_monotonic - time.monotonic()))

    def _maybe_finish_rest_locked(self) -> list[dict[str, Any]]:
        if self._phase != "resting" or self._rest_deadline_monotonic is None:
            return []
        if time.monotonic() < self._rest_deadline_monotonic:
            return []

        self._rest_deadline_monotonic = None
        self._phase = "monitoring"
        self._current_rep = 0
        self._reset_rep_counter_locked()
        self._last_rep_speed_label = "분석 중"
        self._session_accumulator.current_set_started_at = now_iso()
        return [
            {
                "event": "rest_finished",
                "current_set_index": self._current_set_index + 1,
                "finished_at": now_iso(),
            }
        ]

    def _maybe_advance_workout_locked(self, timestamp_ms: int) -> list[dict[str, Any]]:
        target_rep = self._current_target_rep_locked()
        if target_rep is None or self._current_rep is None or self._current_rep < target_rep:
            return []

        actual_rep = self._current_rep
        completed_set_index = self._current_set_index + 1
        self._record_set_completion_locked(completed_set_index, actual_rep, target_rep)
        events = [
            {
                "event": "set_completed",
                "completed_set_index": completed_set_index,
                "actual_rep": actual_rep,
                "target_rep": target_rep,
                "timestamp_ms": timestamp_ms,
                "completed_at": now_iso(),
            }
        ]

        if completed_set_index >= self._set_count:
            self._phase = "completed"
            self._rest_deadline_monotonic = None
            self._finalize_session_locked("completed", "auto_completed")
            events.append(
                {
                    "event": "workout_completed",
                    "completed_sets": self._set_count,
                    "timestamp_ms": timestamp_ms,
                    "ended_at": now_iso(),
                    "status": "completed",
                    "end_reason": "auto_completed",
                }
            )
            return events

        self._current_set_index += 1
        self._current_rep = 0
        self._phase = "resting"
        self._rest_deadline_monotonic = time.monotonic() + self._rest_sec
        self._reset_rep_counter_locked()
        events.append(
            {
                "event": "rest_started",
                "next_set_index": self._current_set_index + 1,
                "rest_sec": self._rest_sec,
                "started_at": now_iso(),
            }
        )
        return events

    def maybe_collect_calibration_frame(self, frame: DecodedFrame) -> Optional[str]:
        with self._lock:
            if not self._calibration_collecting:
                return None

            if (
                self._calibration_started_monotonic is not None
                and time.monotonic() - self._calibration_started_monotonic
                > CALIBRATION_TIMEOUT_SEC
            ):
                frame_count = len(self._calibration_frames)
                reason_suffix = ""
                if frame_count == 0 and self._calibration_last_rejection_reason:
                    reason_suffix = (
                        f" last_rejection={self._calibration_last_rejection_reason}"
                    )
                print(
                    f"[calib] timeout via frame path stage={self._calibration_stage} "
                    f"collected={frame_count}{reason_suffix}"
                )
                self._fail_calibration_locked(
                    "캘리브레이션 제한 시간을 초과했습니다. 센서를 다시 확인하고 재시도하세요."
                )
                return "failed"

            stage = self._calibration_stage
            if stage == "rest":
                rejection_reason = self._rest_frame_rejection_reason_locked(frame)
                if rejection_reason is not None:
                    self._reset_rest_window_locked(rejection_reason)
                    return None
                self._calibration_last_rejection_reason = None
                self._calibration_rejection_streak = 0

            self._calibration_frames.append(frame)
            count = len(self._calibration_frames)
            target = CALIBRATION_REST_FRAMES if stage == "rest" else CALIBRATION_MVC_FRAMES
            if count == 1 or count % 25 == 0 or count == target:
                detached_mask = [
                    "X" if frame.emg[index] >= EMG_DETACHED_THRESHOLD else "o"
                    for index in range(4)
                ]
                emg_preview = [f"{frame.emg[index]:.3f}" for index in range(4)]
                gyro_preview = [
                    f"{value:.2f}" for value in self._imu_gyro_norms(frame)
                ]
                print(
                    f"[calib] progress stage={stage} {count}/{target} "
                    f"emg=[{', '.join(emg_preview)}] detach=[{','.join(detached_mask)}] "
                    f"gyro=[{', '.join(gyro_preview)}] flags=0x{frame.flags:02X}"
                )

            if stage == "rest":
                if count < CALIBRATION_REST_FRAMES:
                    return None
                try:
                    self._finalize_rest_calibration_locked()
                except ValueError as exc:
                    print(f"[calib] rest finalize failed: {exc}")
                    self._fail_calibration_locked(str(exc))
                    return "failed"
                print("[calib] rest_complete — switching to MVC stage")
                self._calibration_frames = []
                self._calibration_stage = "mvc"
                self._phase = "calibrating_mvc"
                return "rest_complete"

            if count < CALIBRATION_MVC_FRAMES:
                return None

            try:
                self._finalize_mvc_calibration_locked()
            except ValueError as exc:
                print(f"[calib] mvc finalize failed: {exc}")
                self._fail_calibration_locked(str(exc))
                return "failed"
            print("[calib] mvc_complete — calibration success")
            return "mvc_complete"

    def _legacy_finalize_rest_calibration_locked(self) -> None:
        frames = self._calibration_frames
        if not frames:
            raise ValueError("안정 자세 프레임을 수집하지 못했습니다.")

        emg_sums = [0.0, 0.0, 0.0, 0.0]
        emg_counts = [0, 0, 0, 0]
        imu_acc_sums = [[0.0, 0.0, 0.0] for _ in range(3)]
        imu_gyro_sums = [[0.0, 0.0, 0.0] for _ in range(3)]

        for frame in frames:
            for channel_index in range(4):
                emg_value = frame.emg[channel_index]
                if emg_value >= EMG_DETACHED_THRESHOLD:
                    continue
                emg_sums[channel_index] += emg_value
                emg_counts[channel_index] += 1
            for imu_index in range(3):
                if imu_index < len(frame.imu_accels):
                    for axis in range(3):
                        imu_acc_sums[imu_index][axis] += frame.imu_accels[imu_index][axis]
                if imu_index < len(frame.imu_gyros):
                    for axis in range(3):
                        imu_gyro_sums[imu_index][axis] += frame.imu_gyros[imu_index][axis]

        frame_count = float(len(frames))
        if any(count < CALIBRATION_MIN_VALID_EMG_FRAMES for count in emg_counts):
            raise ValueError("안정 자세 EMG 기준값이 부족합니다. 센서 밀착 상태를 확인하세요.")
        self._calibration_data.emg_rest_baseline = [
            (emg_sums[index] / emg_counts[index]) if emg_counts[index] > 0 else 0.0
            for index in range(4)
        ]
        self._calibration_data.emg_activation_threshold = [
            baseline + 0.03 for baseline in self._calibration_data.emg_rest_baseline
        ]
        self._calibration_data.imu_rest_accel = [
            [value / frame_count for value in imu_values] for imu_values in imu_acc_sums
        ]
        self._calibration_data.imu_rest_gyro = [
            [value / frame_count for value in imu_values] for imu_values in imu_gyro_sums
        ]
        self._calibration_data.ready = False

    def _legacy_finalize_mvc_calibration_locked(self) -> None:
        frames = self._calibration_frames
        if not frames:
            raise ValueError("최대 수축 프레임을 수집하지 못했습니다.")
        top_values: list[list[float]] = [[] for _ in range(4)]
        for channel_index in range(4):
            samples = sorted(
                [
                    frame.emg[channel_index]
                    for frame in frames
                    if frame.emg[channel_index] < EMG_DETACHED_THRESHOLD
                ]
            )
            if not samples:
                raise ValueError("최대 수축 EMG 샘플이 부족합니다. 힘을 준 상태로 다시 측정하세요.")
            top_count = max(1, math.ceil(len(samples) * 0.1))
            top_values[channel_index] = samples[-top_count:]

        self._calibration_data.emg_mvc = [
            max(
                self._calibration_data.emg_rest_baseline[index] + 0.05,
                sum(top_values[index]) / len(top_values[index]),
            )
            for index in range(4)
        ]
        self._calibration_data.ready = True
        self._calibration_collecting = False
        self._calibration_frames = []
        self._calibration_stage = "done"
        self._calibration_started_monotonic = None
        self._calibration_failure_message = None
        # 앱의 "운동 시작" 버튼 입력 전까지 monitoring 진입을 보류한다.
        # 사용자가 글래스를 착용하고 start_workout 메시지를 보내야 monitoring 으로 전환.
        self._phase = "awaiting_workout_start"

    def _legacy_fail_calibration_locked(self, message: str) -> None:
        print(f"[calib] FAIL: {message}")
        self._calibration_collecting = False
        self._calibration_frames = []
        self._calibration_stage = "failed"
        self._calibration_started_monotonic = None
        self._calibration_data.ready = False
        self._calibration_failure_message = message
        self._phase = "sensors_ready"

    def _finalize_rest_calibration_locked(self) -> None:
        frames = self._calibration_frames
        if not frames:
            raise ValueError("Rest calibration failed. No stable frames were collected.")

        emg_sums = [0.0, 0.0, 0.0, 0.0]
        emg_sum_squares = [0.0, 0.0, 0.0, 0.0]
        emg_counts = [0, 0, 0, 0]
        imu_acc_sums = [[0.0, 0.0, 0.0] for _ in range(3)]
        imu_gyro_sums = [[0.0, 0.0, 0.0] for _ in range(3)]

        for frame in frames:
            for channel_index in range(4):
                emg_value = frame.emg[channel_index]
                if emg_value >= EMG_DETACHED_THRESHOLD:
                    continue
                emg_sums[channel_index] += emg_value
                emg_sum_squares[channel_index] += emg_value * emg_value
                emg_counts[channel_index] += 1
            for imu_index in range(3):
                if imu_index < len(frame.imu_accels):
                    for axis in range(3):
                        imu_acc_sums[imu_index][axis] += frame.imu_accels[imu_index][axis]
                if imu_index < len(frame.imu_gyros):
                    for axis in range(3):
                        imu_gyro_sums[imu_index][axis] += frame.imu_gyros[imu_index][axis]

        frame_count = float(len(frames))
        if any(count < CALIBRATION_MIN_VALID_EMG_FRAMES for count in emg_counts):
            insufficient_channels = ", ".join(
                f"EMG {index + 1} valid {count}/{len(frames)}"
                for index, count in enumerate(emg_counts)
                if count < CALIBRATION_MIN_VALID_EMG_FRAMES
            )
            raise ValueError(
                "Rest calibration failed: "
                f"{insufficient_channels}. "
                "Check EMG attachment and keep still, then retry."
            )

        baselines = [
            (emg_sums[index] / emg_counts[index]) if emg_counts[index] > 0 else 0.0
            for index in range(4)
        ]
        rest_std = []
        rest_failures: list[str] = []
        for index, baseline in enumerate(baselines):
            variance = max(
                0.0,
                (emg_sum_squares[index] / emg_counts[index]) - (baseline * baseline),
            )
            std = math.sqrt(variance)
            rest_std.append(std)
            print(
                f"[calib] rest ch{index + 1} baseline={baseline:.4f} std={std:.4f}"
            )
            if baseline > CALIBRATION_REST_MAX_EMG_MEAN:
                rest_failures.append(
                    f"EMG {index + 1} baseline {baseline:.3f} > "
                    f"{CALIBRATION_REST_MAX_EMG_MEAN:.3f}"
                )
            if std > CALIBRATION_REST_MAX_EMG_STD:
                rest_failures.append(
                    f"EMG {index + 1} noise {std:.3f} > "
                    f"{CALIBRATION_REST_MAX_EMG_STD:.3f}"
                )

        if rest_failures:
            print(f"[calib] rest quality issues: {'; '.join(rest_failures)}")
            raise ValueError(
                "Rest calibration failed: "
                f"{'; '.join(rest_failures)}. "
                "Relax the muscles, keep still, and retry."
            )

        self._calibration_rest_std = rest_std
        self._calibration_data.emg_rest_baseline = baselines
        self._calibration_data.emg_activation_threshold = [
            baseline + 0.03 for baseline in self._calibration_data.emg_rest_baseline
        ]
        self._calibration_data.imu_rest_accel = [
            [value / frame_count for value in imu_values] for imu_values in imu_acc_sums
        ]
        self._calibration_data.imu_rest_gyro = [
            [value / frame_count for value in imu_values] for imu_values in imu_gyro_sums
        ]
        self._calibration_data.ready = False

    def _finalize_mvc_calibration_locked(self) -> None:
        frames = self._calibration_frames
        if not frames:
            raise ValueError("MVC calibration failed. No frames were collected.")

        minimum_valid_samples = math.ceil(
            CALIBRATION_MVC_FRAMES * CALIBRATION_MVC_MIN_VALID_RATIO
        )
        # Keep a conservative fallback MVC for channels that end up warning-only.
        mvc_values = list(self._calibration_data.emg_mvc)
        mvc_failures: list[str] = []
        mvc_warnings: list[str] = []
        primary_active_thresholds = [0.0, 0.0]

        for channel_index in range(4):
            is_primary_channel = channel_index < 2
            valid_samples = [
                frame.emg[channel_index]
                for frame in frames
                if frame.emg[channel_index] < EMG_DETACHED_THRESHOLD
            ]
            if len(valid_samples) < minimum_valid_samples:
                issue = (
                    f"EMG {channel_index + 1} valid "
                    f"{len(valid_samples)}/{len(frames)}"
                )
                if is_primary_channel:
                    mvc_failures.append(issue)
                else:
                    mvc_warnings.append(issue)
                continue

            samples = sorted(valid_samples)
            top_count = max(1, math.ceil(len(samples) * 0.1))
            top_average = sum(samples[-top_count:]) / top_count
            peak_value = samples[-1]
            baseline = self._calibration_data.emg_rest_baseline[channel_index]
            rest_std = self._calibration_rest_std[channel_index]
            minimum_delta = max(
                CALIBRATION_MVC_MIN_PRIMARY_DELTA
                if is_primary_channel
                else CALIBRATION_MVC_MIN_SECONDARY_DELTA,
                rest_std * CALIBRATION_MVC_NOISE_MULTIPLIER,
            )
            minimum_peak_delta = max(
                CALIBRATION_MVC_MIN_PRIMARY_PEAK_DELTA
                if is_primary_channel
                else CALIBRATION_MVC_MIN_SECONDARY_PEAK_DELTA,
                rest_std * (CALIBRATION_MVC_NOISE_MULTIPLIER + 1.0),
            )
            active_threshold = baseline + max(
                CALIBRATION_MVC_ACTIVE_DELTA_FLOOR,
                rest_std * 3.0,
            )
            if is_primary_channel:
                primary_active_thresholds[channel_index] = active_threshold
            active_frames = sum(
                1 for value in valid_samples if value >= active_threshold
            )
            minimum_active_frames = (
                CALIBRATION_MVC_MIN_PRIMARY_ACTIVE_FRAMES
                if is_primary_channel
                else CALIBRATION_MVC_MIN_SECONDARY_ACTIVE_FRAMES
            )
            lift = top_average - baseline
            peak_lift = peak_value - baseline

            print(
                f"[calib] mvc ch{channel_index + 1} baseline={baseline:.4f} "
                f"top_avg={top_average:.4f} peak={peak_value:.4f} "
                f"lift={lift:.4f} active_frames={active_frames}"
            )

            channel_issues: list[str] = []
            if lift < minimum_delta:
                channel_issues.append(
                    f"EMG {channel_index + 1} lift {lift:.3f} < {minimum_delta:.3f}"
                )
            if peak_lift < minimum_peak_delta:
                channel_issues.append(
                    f"EMG {channel_index + 1} peak {peak_lift:.3f} < {minimum_peak_delta:.3f}"
                )
            if active_frames < minimum_active_frames:
                channel_issues.append(
                    f"EMG {channel_index + 1} active {active_frames} < "
                    f"{minimum_active_frames}"
                )

            if channel_issues:
                if is_primary_channel:
                    mvc_failures.extend(channel_issues)
                    continue
                mvc_warnings.extend(channel_issues)

            mvc_values[channel_index] = max(baseline + minimum_delta, top_average)

        primary_sync_frames = sum(
            1
            for frame in frames
            if frame.emg[0] < EMG_DETACHED_THRESHOLD
            and frame.emg[1] < EMG_DETACHED_THRESHOLD
            and frame.emg[0] >= primary_active_thresholds[0]
            and frame.emg[1] >= primary_active_thresholds[1]
        )
        if primary_sync_frames < CALIBRATION_MVC_MIN_PRIMARY_SYNC_FRAMES:
            mvc_failures.append(
                f"primary sync {primary_sync_frames} < "
                f"{CALIBRATION_MVC_MIN_PRIMARY_SYNC_FRAMES}"
            )

        if mvc_warnings:
            print(f"[calib] mvc warnings: {'; '.join(mvc_warnings)}")
        if mvc_failures:
            print(f"[calib] mvc quality issues: {'; '.join(mvc_failures)}")
            raise ValueError(
                "MVC calibration failed: "
                f"{'; '.join(mvc_failures)}. "
                "Check sensor attachment, squeeze harder, and retry."
            )

        self._calibration_data.emg_mvc = mvc_values
        self._calibration_data.ready = True
        self._calibration_collecting = False
        self._calibration_frames = []
        self._calibration_stage = "done"
        self._calibration_started_monotonic = None
        self._calibration_failure_message = None
        self._phase = "awaiting_workout_start"

    def _fail_calibration_locked(self, message: str) -> None:
        print(f"[calib] FAIL: {message}")
        self._calibration_collecting = False
        self._calibration_frames = []
        self._calibration_stage = "failed"
        self._calibration_started_monotonic = None
        self._reset_calibration_results_locked()
        self._calibration_failure_message = message
        self._phase = "sensors_ready"

    @staticmethod
    def _phase_label(phase: str) -> str:
        return {
            "idle": "운동 선택 대기",
            "ready_for_calibration": "센서 부착 대기",
            "sensors_ready": "캘리브레이션 준비",
            "calibrating": "안정 자세 측정 중",
            "calibrating_mvc": "최대 수축 측정 중",
            "awaiting_workout_start": "운동 시작 대기",
            "monitoring": "실시간 측정 중",
            "resting": "세트 간 휴식 중",
            "paused": "일시정지",
            "completed": "운동 종료",
        }.get(phase, phase)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def wrap_message(
    msg_type: str,
    payload: dict[str, Any],
    *,
    request_id: Optional[str] = None,
) -> dict[str, Any]:
    return {
        "type": msg_type,
        "payload": payload,
        "timestamp": now_iso(),
        "requestId": request_id,
    }


def build_connection_status(state: ConnectionSnapshot) -> dict[str, Any]:
    return wrap_message("connection_status", asdict(state))


def build_glass_session_state(state: SessionSnapshot) -> dict[str, Any]:
    return wrap_message("glass_session_state", asdict(state))


def build_glass_display_data(
    session: SessionSnapshot,
    frame: Optional[DecodedFrame],
    calibration: Optional[CalibrationData] = None,
    calibration_progress: float = 0.0,
) -> dict[str, Any]:
    phase_result = build_phase_result(session.phase)
    if session.exercise_type is None:
        result = build_waiting_result()
    elif phase_result is not None and session.phase != "monitoring":
        result = phase_result
    else:
        result = analyze_frame(session.exercise_type, frame, calibration)

    sensors = [
        {"name": name, "position": position}
        for name, position in SENSOR_CONFIGS.get(session.exercise_type or "", [])
    ]
    emg_channels = build_emg_channel_activations(
        session.exercise_type,
        frame,
        calibration,
    )

    return wrap_message(
        "glass_display_data",
        {
            "exercise_type": session.exercise_type,
            "exercise_label": session.exercise_label,
            "phase": session.phase,
            "phase_label": session.phase_label,
            "current_set_index": session.current_set_index,
            "current_rep": session.current_rep,
            "current_speed_label": session.current_speed_label,
            "target_rep": session.target_rep,
            "target_reps_per_set": session.target_reps_per_set,
            "rest_remaining_sec": session.rest_remaining_sec,
            "activation_percent": result.activation_percent,
            "channel_activation_percent": result.channel_activation_percent,
            "activation_level": result.activation_level,
            "usage_text": result.usage_text,
            "usage_tone": result.usage_tone,
            "pose_badge": result.pose_badge,
            "pose_title": result.pose_title,
            "pose_detail": result.pose_detail,
            "pose_tone": result.pose_tone,
            "calibration_progress": max(0.0, min(1.0, calibration_progress)),
            "sensors": sensors,
            "emg_channels": emg_channels,
            "frame_seq": None if frame is None else frame.seq,
            "frame_timestamp_ms": None if frame is None else frame.timestamp_ms,
        },
    )


def build_plan_ack(
    accepted: bool,
    exercise_type: str,
    set_count: int,
    validation_errors: list[str],
    request_id: Optional[str],
) -> dict[str, Any]:
    return wrap_message(
        "plan_ack",
        {
            "accepted": accepted,
            "exercise_type": exercise_type,
            "set_count": set_count,
            "validation_errors": validation_errors,
        },
        request_id=request_id,
    )


def build_calibration_status(
    status: str,
    message: str,
    request_id: Optional[str] = None,
    calibration_summary: Optional[dict[str, Any]] = None,
    progress: Optional[float] = None,
) -> dict[str, Any]:
    payload = {
        "status": status,
        "message": message,
    }
    if calibration_summary is not None:
        payload["calibration_summary"] = calibration_summary
    if progress is not None:
        payload["progress"] = max(0.0, min(1.0, progress))

    return wrap_message(
        "calibration_status",
        payload,
        request_id=request_id,
    )


def build_sensor_frame_message(frame: DecodedFrame) -> dict[str, Any]:
    return wrap_message(
        "sensor_frame",
        {
            "seq": frame.seq,
            "timestamp_ms": frame.timestamp_ms,
            "state_code": frame.state_code,
            "state": STATE_NAMES.get(frame.state_code, f"UNKNOWN({frame.state_code})"),
            "flags": frame.flags,
            "flag_detail": {
                "is_mock": bool(frame.flags & 0x01),
                "imu_bias_ready": bool(frame.flags & 0x02),
                "motion_detected": bool(frame.flags & 0x04),
                "imu_partial_ready": bool(frame.flags & 0x08),
            },
            "rep_index": frame.rep_index,
            "emg": list(frame.emg),
            "imus": [
                {
                    "index": imu_index + 1,
                    "accel": list(frame.imu_accels[imu_index]),
                    "gyro": list(frame.imu_gyros[imu_index]),
                }
                for imu_index in range(len(frame.imu_accels))
            ],
        },
    )


def build_workout_event(
    event_type: str,
    session: SessionSnapshot,
    details: dict[str, Any],
) -> dict[str, Any]:
    return wrap_message(
        "workout_event",
        {
            "event": event_type,
            "exercise_type": session.exercise_type,
            "current_set_index": session.current_set_index,
            "current_rep": session.current_rep,
            "target_rep": session.target_rep,
            "phase": session.phase,
            "details": details,
        },
    )


def build_app_event_message(event_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    return wrap_message(event_type, payload)


def build_error_message(code: str, message: str) -> dict[str, Any]:
    return wrap_message(
        "error",
        {
            "code": code,
            "message": message,
        },
    )


def summarize_message_for_log(message: dict[str, Any]) -> str:
    msg_type = str(message.get("type", "unknown"))
    payload = message.get("payload")
    if not isinstance(payload, dict):
        return f"type={msg_type}"

    if msg_type == "plan_ack":
        return (
            f"type={msg_type} accepted={payload.get('accepted')} "
            f"exercise_type={payload.get('exercise_type')} set_count={payload.get('set_count')}"
        )
    if msg_type == "calibration_status":
        return f"type={msg_type} status={payload.get('status')} message={payload.get('message')}"
    if msg_type == "connection_status":
        return (
            f"type={msg_type} pi={payload.get('pi_connected')} "
            f"esp32={payload.get('esp32_connected')} glass={payload.get('glass_connected')}"
        )
    if msg_type in {"workout_started", "workout_paused", "workout_resumed"}:
        return f"type={msg_type} payload={payload}"
    if msg_type in {"set_completed", "rest_started", "rest_finished", "workout_completed"}:
        return f"type={msg_type} payload={payload}"
    if msg_type == "session_result":
        return (
            f"type={msg_type} exercise_type={payload.get('exercise_type')} "
            f"status={payload.get('status')} total_reps={payload.get('total_reps')}"
        )
    if msg_type == "glass_session_state":
        return (
            f"type={msg_type} phase={payload.get('phase')} "
            f"exercise_type={payload.get('exercise_type')} current_rep={payload.get('current_rep')}"
        )
    if msg_type == "glass_display_data":
        return (
            f"type={msg_type} pose_title={payload.get('pose_title')} "
            f"activation_percent={payload.get('activation_percent')} current_rep={payload.get('current_rep')}"
        )
    if msg_type == "sensor_frame":
        flag_detail = payload.get("flag_detail") or {}
        return (
            f"type={msg_type} seq={payload.get('seq')} "
            f"ts={payload.get('timestamp_ms')} rep_index={payload.get('rep_index')} "
            f"flags=0x{int(payload.get('flags', 0)):02X} "
            f"motion={flag_detail.get('motion_detected')} "
            f"imu_ready={flag_detail.get('imu_bias_ready')}"
        )
    if msg_type == "error":
        return f"type={msg_type} code={payload.get('code')} message={payload.get('message')}"
    return f"type={msg_type} payload={payload}"


class SensorBridge:
    def __init__(
        self,
        serial_port: str,
        baud_rate: int,
        rep_debug: bool = False,
        glass_debug: bool = False,
        preset_calibration: bool = False,
        replay_log_path: Optional[Path] = None,
    ) -> None:
        self._serial_port = serial_port
        self._baud_rate = baud_rate
        self._state = BridgeState(
            rep_debug=rep_debug,
            preset_calibration=preset_calibration,
        )
        self._clients: set[ServerConnection] = set()
        self._queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._last_frame: Optional[DecodedFrame] = None
        self._workout_started_emitted = False
        self._rep_debug = rep_debug
        self._glass_debug = glass_debug
        self._preset_calibration = preset_calibration
        self._replay_log_path = replay_log_path
        self._replay_restart_requested = False
        self._last_glass_debug_log_monotonic = 0.0

    def _maybe_log_glass_emg_channels(self, message: dict[str, Any]) -> None:
        if not self._glass_debug:
            return

        payload = message.get("payload")
        if not isinstance(payload, dict):
            return

        emg_channels = payload.get("emg_channels")
        if not isinstance(emg_channels, list) or not emg_channels:
            return

        now = time.monotonic()
        if now - self._last_glass_debug_log_monotonic < 1.0:
            return
        self._last_glass_debug_log_monotonic = now

        channel_parts: list[str] = []
        for channel in emg_channels[:4]:
            if not isinstance(channel, dict):
                continue
            raw_value = channel.get("raw_value")
            attached = channel.get("attached")
            activation_percent = channel.get("activation_percent")

            if isinstance(raw_value, (int, float)):
                raw_str = f"{float(raw_value):.3f}"
            else:
                raw_str = "None"
            attached_str = "T" if bool(attached) else "F"
            activation_str = (
                str(int(activation_percent))
                if isinstance(activation_percent, (int, float))
                else "-"
            )
            channel_parts.append(f"({raw_str},{attached_str},{activation_str})")

        if not channel_parts:
            return

        print(
            "[glass] "
            f"phase={payload.get('phase')} seq={payload.get('frame_seq')} "
            "ch raw/att/act = "
            + " ".join(channel_parts)
        )

    def _build_app_event_from_state(self, event_type: str, details: dict[str, Any]) -> dict[str, Any]:
        now = now_iso()
        if event_type == "workout_started":
            return build_app_event_message(
                "workout_started",
                {
                    "exercise_type": details.get("exercise_type"),
                    "started_at": details.get("started_at", now),
                },
            )
        if event_type == "workout_paused":
            return build_app_event_message(
                "workout_paused",
                {
                    "set_index": int(details.get("set_index", 0) or 0),
                    "current_rep": int(details.get("current_rep", 0) or 0),
                    "paused_at": details.get("paused_at", now),
                },
            )
        if event_type == "workout_resumed":
            return build_app_event_message(
                "workout_resumed",
                {
                    "set_index": int(details.get("set_index", 0) or 0),
                    "current_rep": int(details.get("current_rep", 0) or 0),
                    "resumed_at": details.get("resumed_at", now),
                },
            )
        if event_type == "set_completed":
            return build_app_event_message(
                "set_completed",
                {
                    "set_index": int(details.get("completed_set_index", 0) or 0),
                    "target_reps": int(details.get("target_rep", 0) or 0),
                    "actual_reps": int(details.get("actual_rep", 0) or 0),
                    "completed_at": details.get("completed_at", now),
                },
            )
        if event_type == "rest_started":
            next_set_index = int(details.get("next_set_index", 0) or 0)
            return build_app_event_message(
                "rest_started",
                {
                    "after_set_index": max(0, next_set_index - 1),
                    "rest_sec": int(details.get("rest_sec", 0) or 0),
                    "started_at": details.get("started_at", now),
                },
            )
        if event_type == "rest_finished":
            return build_app_event_message(
                "rest_finished",
                {
                    "next_set_index": int(details.get("current_set_index", 0) or 0),
                    "finished_at": details.get("finished_at", now),
                },
            )
        if event_type == "workout_completed":
            return build_app_event_message(
                "workout_completed",
                {
                    "ended_at": details.get("ended_at", now),
                    "status": details.get("status", "completed"),
                    "end_reason": details.get("end_reason", "auto_completed"),
                },
            )
        return build_workout_event(event_type, self._state.session_snapshot(), details)

    def _emit_workout_started_if_needed(self) -> None:
        session = self._state.session_snapshot()
        if self._workout_started_emitted or session.exercise_type is None or session.phase != "monitoring":
            return
        self._workout_started_emitted = True
        self._emit_from_thread(
            self._build_app_event_from_state(
                "workout_started",
                {
                    "exercise_type": session.exercise_type,
                    "started_at": now_iso(),
                },
            )
        )

    def _build_glass_display_message(
        self,
        frame: Optional[DecodedFrame] = None,
    ) -> dict[str, Any]:
        message = build_glass_display_data(
            self._state.session_snapshot(),
            self._last_frame if frame is None else frame,
            self._state.calibration_snapshot(),
            calibration_progress=self._state.calibration_progress_snapshot(),
        )
        self._maybe_log_glass_emg_channels(message)
        return message


    async def run(
        self,
        ws_host: str,
        ws_port: int,
        ui_host: str,
        ui_port: int,
    ) -> None:
        self._loop = asyncio.get_running_loop()
        self._start_ui_http_server(ui_host, ui_port)

        worker_target = self._replay_reader_main if self._replay_log_path else self._serial_reader_main
        worker = threading.Thread(target=worker_target, daemon=True)
        worker.start()

        async with serve(self._handle_client, ws_host, ws_port):
            print(f"[bridge] websocket listening: ws://{ws_host}:{ws_port}")
            print(f"[bridge] glass ui: http://{ui_host}:{ui_port}")
            if self._rep_debug:
                print("[bridge] rep debug logging enabled")
            if self._glass_debug:
                print("[bridge] glass emg debug logging enabled")
            if self._preset_calibration:
                print("[bridge] preset calibration enabled")
            if self._replay_log_path is not None:
                print(f"[bridge] replay log enabled: {self._replay_log_path}")
            timer_task = asyncio.create_task(self._state_tick_loop())
            try:
                await self._broadcast_loop()
            finally:
                timer_task.cancel()

    async def _handle_client(self, websocket: ServerConnection) -> None:
        self._clients.add(websocket)
        self._state.set_glass_connected(True)
        await websocket.send(json.dumps(build_connection_status(self._state.connection_snapshot())))
        await websocket.send(json.dumps(build_glass_session_state(self._state.session_snapshot())))
        await websocket.send(json.dumps(self._build_glass_display_message()))
        try:
            async for raw_message in websocket:
                await self._handle_client_message(websocket, raw_message)
        finally:
            self._clients.discard(websocket)
            self._state.set_glass_connected(bool(self._clients))
            self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))

    async def _handle_client_message(
        self,
        websocket: ServerConnection,
        raw_message: str,
    ) -> None:
        try:
            message = json.loads(raw_message)
        except json.JSONDecodeError:
            await websocket.send(
                json.dumps(build_error_message("INVALID_JSON", "Message must be valid JSON."))
            )
            return

        msg_type = message.get("type")
        payload = message.get("payload") or {}
        request_id = message.get("requestId")
        print(f"[bridge] app -> pi type={msg_type} payload={payload}")

        if msg_type == "ping":
            await websocket.send(json.dumps(wrap_message("pong", {}, request_id=request_id)))
            return

        if msg_type == "submit_workout_plan":
            validation_errors = self._validate_workout_plan(payload)
            accepted = len(validation_errors) == 0
            exercise_type = str(payload.get("exercise_type", ""))
            set_count = int(payload.get("set_count", 0) or 0)
            target_reps_per_set = [
                int(value) for value in payload.get("target_reps_per_set", []) if isinstance(value, int)
            ]
            rest_sec = int(payload.get("rest_sec", 0) or 0)

            if accepted:
                self._state.set_workout_plan(
                    exercise_type=exercise_type,
                    set_count=set_count,
                    target_reps_per_set=target_reps_per_set,
                    rest_sec=rest_sec,
                )
                self._workout_started_emitted = False
                self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
                self._emit_from_thread(self._build_glass_display_message())

            await websocket.send(
                json.dumps(
                    build_plan_ack(
                        accepted=accepted,
                        exercise_type=exercise_type,
                        set_count=set_count,
                        validation_errors=validation_errors,
                        request_id=request_id,
                    )
                )
            )
            return

        session = self._state.session_snapshot()

        if msg_type == "sensors_attached":
            if session.exercise_type is None or session.phase != "ready_for_calibration":
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "sensors_attached must be sent after a workout plan is accepted.",
                        )
                    )
                )
                return
            self._state.mark_sensors_attached()
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message())
            return

        if msg_type == "start_calibration":
            if session.exercise_type is None or session.phase not in {"ready_for_calibration", "sensors_ready"}:
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "start_calibration must be sent after a workout plan is accepted.",
                        )
                    )
                )
                return
            if session.phase == "ready_for_calibration":
                self._state.mark_sensors_attached()
            self._state.start_calibration_collection()
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message())
            await websocket.send(
                json.dumps(
                    build_calibration_status(
                        status="started",
                        message=(
                            "힘을 빼고 5초간 유지하세요. 저장된 기준값을 자동 적용합니다."
                            if self._preset_calibration
                            else "안정 자세 기준값 측정을 시작합니다. 이후 최대 수축 측정으로 자동 전환됩니다."
                        ),
                        request_id=request_id,
                        progress=0.0,
                    )
                )
            )
            return

        if msg_type == "start_workout":
            if session.exercise_type is None or session.phase not in {"awaiting_workout_start", "monitoring"}:
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "start_workout must be sent after calibration completes.",
                        )
                    )
                )
                return
            if not self._state.start_workout():
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "start_workout transition rejected by session state.",
                        )
                    )
                )
                return
            self._workout_started_emitted = False
            self._replay_restart_requested = True
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message())
            self._emit_workout_started_if_needed()
            return

        if msg_type == "pause_workout":
            if session.phase not in {"monitoring", "resting", "calibrating", "calibrating_mvc"}:
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "pause_workout is only available during calibration, monitoring, or rest.",
                        )
                    )
                )
                return
            self._state.mark_paused()
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message())
            paused_session = self._state.session_snapshot()
            self._emit_from_thread(
                self._build_app_event_from_state(
                    "workout_paused",
                    {
                        "set_index": paused_session.current_set_index,
                        "current_rep": paused_session.current_rep or 0,
                        "paused_at": now_iso(),
                    },
                )
            )
            return

        if msg_type == "resume_workout":
            if session.phase != "paused":
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "resume_workout is only available from paused state.",
                        )
                    )
                )
                return
            self._state.mark_monitoring()
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message())
            resumed_session = self._state.session_snapshot()
            self._emit_from_thread(
                self._build_app_event_from_state(
                    "workout_resumed",
                    {
                        "set_index": resumed_session.current_set_index,
                        "current_rep": resumed_session.current_rep or 0,
                        "resumed_at": now_iso(),
                    },
                )
            )
            self._emit_workout_started_if_needed()
            return

        if msg_type in {"stop_workout", "emergency_stop"}:
            if session.exercise_type is None or session.phase in {"idle", "completed"}:
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            f"{msg_type} is not available before a workout starts or after it ends.",
                        )
                    )
                )
                return
            self._state.mark_completed()
            self._state.finalize_session(
                "stopped" if msg_type == "stop_workout" else "emergency_stopped",
                "user_request" if msg_type == "stop_workout" else "user_emergency",
            )
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message())
            self._emit_from_thread(
                build_workout_event(
                    "workout_stopped" if msg_type == "stop_workout" else "emergency_stopped",
                    self._state.session_snapshot(),
                    {"request_id": request_id},
                )
            )
            session_result = self._state.consume_pending_session_result()
            if session_result is not None:
                self._emit_from_thread(session_result)
            return

        await websocket.send(
            json.dumps(
                build_error_message(
                    "UNKNOWN_MESSAGE_TYPE",
                    f"Unsupported message type: {msg_type}",
                )
            )
        )

    @staticmethod
    def _validate_workout_plan(payload: dict[str, Any]) -> list[str]:
        errors: list[str] = []
        exercise_type = payload.get("exercise_type")
        set_count = payload.get("set_count")
        target_reps_per_set = payload.get("target_reps_per_set")
        rest_sec = payload.get("rest_sec")

        if exercise_type not in EXERCISE_LABELS:
            errors.append("unsupported exercise_type")
        if not isinstance(set_count, int) or set_count <= 0:
            errors.append("set_count must be greater than 0")
        if not isinstance(target_reps_per_set, list) or len(target_reps_per_set) == 0:
            errors.append("target_reps_per_set must not be empty")
        elif any(not isinstance(rep, int) or rep <= 0 for rep in target_reps_per_set):
            errors.append("target_reps_per_set values must be positive integers")
        elif isinstance(set_count, int) and len(target_reps_per_set) != set_count:
            errors.append("target_reps_per_set length must match set_count")
        if not isinstance(rest_sec, int) or rest_sec <= 0:
            errors.append("rest_sec must be greater than 0")
        return errors

    async def _broadcast_loop(self) -> None:
        while True:
            message = await self._queue.get()
            if not self._clients:
                continue

            print(f"[bridge] pi -> app {summarize_message_for_log(message)}")
            payload = json.dumps(message)
            disconnected: list[ServerConnection] = []
            for client in list(self._clients):
                try:
                    await client.send(payload)
                except Exception:
                    disconnected.append(client)

            for client in disconnected:
                self._clients.discard(client)

    async def _state_tick_loop(self) -> None:
        while True:
            await asyncio.sleep(0.2)
            preset_update = self._state.advance_preset_calibration()
            if preset_update == "rest_complete":
                self._emit_from_thread(
                    build_calibration_status(
                        status="started",
                        message="힘을 주세요. 5초 후 저장된 MVC 기준값을 자동 적용합니다.",
                        progress=0.5,
                    )
                )
                self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
                self._emit_from_thread(self._build_glass_display_message())
            if preset_update == "mvc_complete":
                calibration = self._state.calibration_snapshot()
                self._replay_restart_requested = True
                self._emit_from_thread(
                    build_calibration_status(
                        status="success",
                        message="저장된 REST/MVC 기준값 적용 완료",
                        calibration_summary={
                            "ch1_mvc": calibration.emg_mvc[0],
                            "ch2_mvc": calibration.emg_mvc[1],
                            "ch3_mvc": calibration.emg_mvc[2],
                            "ch4_mvc": calibration.emg_mvc[3],
                        },
                        progress=1.0,
                    )
                )
                self._emit_workout_started_if_needed()
                self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
                self._emit_from_thread(self._build_glass_display_message())
            if self._state.check_calibration_timeout():
                failure_message = self._state.consume_calibration_failure_message()
                self._emit_from_thread(
                    build_calibration_status(
                        status="failed",
                        message=failure_message or "캘리브레이션에 실패했습니다. 다시 시도하세요.",
                    )
                )
                self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
                self._emit_from_thread(self._build_glass_display_message())
            workout_events = self._state.tick()
            if not workout_events:
                continue

            current_session = self._state.session_snapshot()
            self._emit_from_thread(build_glass_session_state(current_session))
            self._emit_from_thread(self._build_glass_display_message())
            for workout_event in workout_events:
                event_type = str(workout_event.get("event", "unknown"))
                details = {key: value for key, value in workout_event.items() if key != "event"}
                self._emit_from_thread(self._build_app_event_from_state(event_type, details))
            self._emit_workout_started_if_needed()

    def _emit_from_thread(self, message: dict[str, Any]) -> None:
        if self._loop is None:
            return
        mtype = message.get("type")
        if mtype not in ("sensor_frame", "glass_display_data"):
            print(f"[bridge] pi -> app type={mtype} payload={message.get('payload')}")
        self._loop.call_soon_threadsafe(self._queue.put_nowait, message)

    def _process_decoded_frame(self, decoded: DecodedFrame) -> None:
        first_connected = not self._state.connection_snapshot().esp32_connected
        previous_phase = self._state.session_snapshot().phase
        workout_events = self._state.update_frame(decoded)
        self._last_frame = decoded
        calibration_update = self._state.maybe_collect_calibration_frame(decoded)
        if first_connected:
            self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))
        current_session = self._state.session_snapshot()
        if previous_phase != current_session.phase:
            self._emit_from_thread(build_glass_session_state(current_session))
        self._emit_from_thread(self._build_glass_display_message(decoded))
        self._emit_from_thread(build_sensor_frame_message(decoded))
        for workout_event in workout_events:
            event_type = str(workout_event.get("event", "unknown"))
            details = {key: value for key, value in workout_event.items() if key != "event"}
            self._emit_from_thread(self._build_app_event_from_state(event_type, details))
        session_result = self._state.consume_pending_session_result()
        if session_result is not None:
            self._emit_from_thread(session_result)
        if calibration_update == "rest_complete":
            self._emit_from_thread(
                build_calibration_status(
                    status="started",
                    message="안정 자세 측정이 끝났습니다. 이제 최대 수축을 5초간 유지하세요.",
                    progress=0.5,
                )
            )
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message(decoded))
        if calibration_update == "mvc_complete":
            calibration = self._state.calibration_snapshot()
            self._emit_from_thread(
                build_calibration_status(
                    status="success",
                    message="REST/MVC 기준값 측정 완료",
                    calibration_summary={
                        "ch1_mvc": calibration.emg_mvc[0],
                        "ch2_mvc": calibration.emg_mvc[1],
                        "ch3_mvc": calibration.emg_mvc[2],
                        "ch4_mvc": calibration.emg_mvc[3],
                    },
                    progress=1.0,
                )
            )
            self._emit_workout_started_if_needed()
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message(decoded))
        if calibration_update == "failed":
            failure_message = self._state.consume_calibration_failure_message()
            self._emit_from_thread(
                build_calibration_status(
                    status="failed",
                    message=failure_message or "캘리브레이션에 실패했습니다. 다시 시도하세요.",
                )
            )
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(self._build_glass_display_message(decoded))

    @staticmethod
    def _decoded_frame_from_log_record(record: dict[str, Any]) -> Optional[DecodedFrame]:
        if record.get("type") != "sensor_frame":
            return None
        emg = record.get("emg")
        imus = record.get("imus")
        if not isinstance(emg, list) or len(emg) < 4:
            return None
        imu_accels: list[tuple[float, float, float]] = []
        imu_gyros: list[tuple[float, float, float]] = []
        if isinstance(imus, list):
            for imu in imus[:3]:
                if not isinstance(imu, dict):
                    continue
                accel = imu.get("accel")
                gyro = imu.get("gyro")
                if isinstance(accel, list) and len(accel) >= 3:
                    imu_accels.append(tuple(float(value) for value in accel[:3]))
                if isinstance(gyro, list) and len(gyro) >= 3:
                    imu_gyros.append(tuple(float(value) for value in gyro[:3]))
        while len(imu_accels) < 3:
            imu_accels.append((0.0, 0.0, 0.0))
        while len(imu_gyros) < 3:
            imu_gyros.append((0.0, 0.0, 0.0))
        state_code = int(record.get("state_code", 1) or 1)
        flags = int(record.get("flags", 0) or 0)
        rep_index = record.get("rep_index")
        return DecodedFrame(
            seq=int(record.get("seq", 0) or 0),
            timestamp_ms=int(record.get("timestamp_ms", 0) or 0),
            emg=tuple(float(value) for value in emg[:4]),
            imu_accels=tuple(imu_accels),
            imu_gyros=tuple(imu_gyros),
            state_code=state_code,
            flags=flags,
            rep_index=rep_index if isinstance(rep_index, int) else None,
        )

    def _load_replay_frames(self) -> list[DecodedFrame]:
        if self._replay_log_path is None:
            return []
        frames: list[DecodedFrame] = []
        with self._replay_log_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(record, dict):
                    continue
                frame = self._decoded_frame_from_log_record(record)
                if frame is not None:
                    frames.append(frame)
        return frames

    def _replay_reader_main(self) -> None:
        try:
            frames = self._load_replay_frames()
        except OSError as exc:
            self._emit_from_thread(
                build_error_message(
                    "REPLAY_LOG_ERROR",
                    f"Replay log could not be loaded: {exc}",
                )
            )
            return
        if not frames:
            self._emit_from_thread(
                build_error_message(
                    "REPLAY_LOG_EMPTY",
                    "Replay log has no sensor_frame records.",
                )
            )
            return

        print(f"[bridge] loaded replay frames={len(frames)}")
        index = 0
        last_timestamp_ms: Optional[int] = None
        while True:
            session = self._state.session_snapshot()
            if session.phase != "monitoring":
                threading.Event().wait(0.05)
                continue
            if self._replay_restart_requested:
                index = 0
                last_timestamp_ms = None
                self._replay_restart_requested = False

            frame = frames[index]
            if last_timestamp_ms is not None:
                delay_ms = max(1, min(200, frame.timestamp_ms - last_timestamp_ms))
                threading.Event().wait(delay_ms / 1000.0)
            else:
                threading.Event().wait(0.02)
            last_timestamp_ms = frame.timestamp_ms
            self._process_decoded_frame(frame)
            index = (index + 1) % len(frames)

    def _serial_reader_main(self) -> None:
        while True:
            try:
                self._serial_reader_once()
            except serial.SerialException as exc:
                self._state.mark_esp32_disconnected()
                self._emit_from_thread(
                    build_error_message(
                        "ESP32_SERIAL_ERROR",
                        f"Serial connection failed: {exc}",
                    )
                )
                self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))
                threading.Event().wait(1.0)

    def _serial_reader_once(self) -> None:
        ser = serial.Serial(
            port=self._serial_port,
            baudrate=self._baud_rate,
            timeout=1,
            dsrdtr=False,
            rtscts=False,
        )
        ser.dtr = False
        ser.rts = False
        ser.reset_input_buffer()
        self._state.mark_esp32_disconnected()
        self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))

        buffer = bytearray()
        try:
            while True:
                chunk = ser.read(256)
                if not chunk:
                    continue
                buffer.extend(chunk)

                while len(buffer) >= FRAME_SIZE:
                    if buffer[0:2] != MAGIC:
                        start = buffer.find(MAGIC)
                        if start < 0:
                            if len(buffer) > 2:
                                del buffer[:-2]
                            break
                        if start > 0:
                            del buffer[:start]
                        if len(buffer) < FRAME_SIZE:
                            break

                    frame_bytes = bytes(buffer[:FRAME_SIZE])
                    decoded = decode_frame(frame_bytes)
                    if decoded is None:
                        del buffer[0]
                        continue

                    del buffer[:FRAME_SIZE]
                    self._process_decoded_frame(decoded)
        finally:
            ser.close()
            self._state.mark_esp32_disconnected()
            self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))

    @staticmethod
    def _start_ui_http_server(host: str, port: int) -> None:
        handler = partial(SimpleHTTPRequestHandler, directory=str(UI_DIR))
        server = ThreadingHTTPServer((host, port), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Bridge ESP32 serial sensor frames to app WebSocket JSON."
    )
    parser.add_argument("--serial-port", default="/dev/ttyUSB0", help="ESP32 serial port path")
    parser.add_argument("--baud", type=int, default=115200, help="ESP32 serial baud rate")
    parser.add_argument("--ws-host", default="0.0.0.0", help="WebSocket bind host")
    parser.add_argument("--ws-port", type=int, default=8765, help="WebSocket bind port")
    parser.add_argument("--ui-host", default="0.0.0.0", help="Glass UI bind host")
    parser.add_argument("--ui-port", type=int, default=8080, help="Glass UI bind port")
    parser.add_argument(
        "--rep-debug",
        action="store_true",
        help="Print detailed exercise rep inference logs for real-device validation.",
    )
    parser.add_argument(
        "--glass-debug",
        action="store_true",
        help="Print throttled glass EMG channel logs as (raw, attached, activation).",
    )
    parser.add_argument(
        "--preset-calibration",
        action="store_true",
        help="Skip live REST/MVC collection and inject demo calibration values after 5s + 5s.",
    )
    parser.add_argument(
        "--replay-log",
        type=Path,
        default=None,
        help=(
            "Replay sensor_frame records from a JSONL log after workout starts instead of "
            "reading serial. This also enables preset calibration for the demo flow."
        ),
    )
    return parser.parse_args()


async def async_main() -> int:
    args = parse_args()
    preset_calibration = args.preset_calibration or args.replay_log is not None
    bridge = SensorBridge(
        serial_port=args.serial_port,
        baud_rate=args.baud,
        rep_debug=args.rep_debug,
        glass_debug=args.glass_debug,
        preset_calibration=preset_calibration,
        replay_log_path=args.replay_log,
    )
    await bridge.run(
        ws_host=args.ws_host,
        ws_port=args.ws_port,
        ui_host=args.ui_host,
        ui_port=args.ui_port,
    )
    return 0


def main() -> int:
    try:
        return asyncio.run(async_main())
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
