#!/usr/bin/env python3
"""Human-readable IMU rep/speed tester for ESP32 sensor frames."""

from __future__ import annotations

import argparse
import statistics
from dataclasses import dataclass
from enum import Enum
from typing import Optional

try:
    import serial
except ModuleNotFoundError as exc:
    raise SystemExit(
        "pyserial is required. Run `pip install pyserial` and try again."
    ) from exc

from esp32_serial_receiver import FRAME_SIZE, MAGIC, DecodedFrame, decode_frame


class RepPhase(Enum):
    READY = "ready"
    LIFTING = "lifting"
    HOLDING = "holding"
    LOWERING = "lowering"


@dataclass(frozen=True)
class Baseline:
    imu_accels: tuple[tuple[float, float, float], ...]
    imu_gyros: tuple[tuple[float, float, float], ...]


@dataclass(frozen=True)
class MotionSnapshot:
    left_accel: float
    right_accel: float
    torso_accel: float
    left_gyro: float
    right_gyro: float
    torso_gyro: float
    main_side: str
    main_accel: float
    support_accel: float
    symmetry_gap: float
    motion_score: float


@dataclass
class RepTracker:
    phase: RepPhase = RepPhase.READY
    rep_count: int = 0
    last_rep_ts_ms: Optional[int] = None
    phase_started_ts_ms: Optional[int] = None
    peak_score: float = 0.0
    peak_accel: float = 0.0
    previous_main_accel: float = 0.0
    falling_frames: int = 0


def vector_delta_norm(
    current: tuple[float, float, float],
    baseline: tuple[float, float, float],
) -> float:
    return (
        abs(current[0] - baseline[0])
        + abs(current[1] - baseline[1])
        + abs(current[2] - baseline[2])
    )


def build_baseline(frames: list[DecodedFrame]) -> Baseline:
    accel_means = []
    gyro_means = []
    for imu_index in range(3):
        accel_means.append(
            tuple(
                statistics.fmean(frame.imu_accels[imu_index][axis] for frame in frames)
                for axis in range(3)
            )
        )
        gyro_means.append(
            tuple(
                statistics.fmean(frame.imu_gyros[imu_index][axis] for frame in frames)
                for axis in range(3)
            )
        )
    return Baseline(imu_accels=tuple(accel_means), imu_gyros=tuple(gyro_means))


def compute_motion(frame: DecodedFrame, baseline: Baseline) -> MotionSnapshot:
    # Keep the IMU roles fixed across all exercises:
    # IMU1 = left arm, IMU2 = right arm, IMU3 = torso.
    left_accel = vector_delta_norm(frame.imu_accels[0], baseline.imu_accels[0])
    right_accel = vector_delta_norm(frame.imu_accels[1], baseline.imu_accels[1])
    torso_accel = vector_delta_norm(frame.imu_accels[2], baseline.imu_accels[2])
    left_gyro = vector_delta_norm(frame.imu_gyros[0], baseline.imu_gyros[0])
    right_gyro = vector_delta_norm(frame.imu_gyros[1], baseline.imu_gyros[1])
    torso_gyro = vector_delta_norm(frame.imu_gyros[2], baseline.imu_gyros[2])

    if left_accel >= right_accel:
        main_side = "왼팔"
        main_accel = left_accel
        support_accel = right_accel
    else:
        main_side = "오른팔"
        main_accel = right_accel
        support_accel = left_accel

    symmetry_gap = abs(left_accel - right_accel)
    motion_score = main_accel + 0.25 * max(left_gyro, right_gyro)
    return MotionSnapshot(
        left_accel=left_accel,
        right_accel=right_accel,
        torso_accel=torso_accel,
        left_gyro=left_gyro,
        right_gyro=right_gyro,
        torso_gyro=torso_gyro,
        main_side=main_side,
        main_accel=main_accel,
        support_accel=support_accel,
        symmetry_gap=symmetry_gap,
        motion_score=motion_score,
    )


def classify_speed(duration_sec: float) -> str:
    if duration_sec < 0.9:
        return "빠름"
    if duration_sec < 1.8:
        return "적정"
    return "느림"


def classify_balance(motion: MotionSnapshot) -> str:
    if motion.symmetry_gap < 0.15:
        return "좌우가 비슷하게 움직이고 있습니다."
    if motion.main_side == "왼팔":
        return "왼팔이 더 크게 움직이고 있습니다."
    return "오른팔이 더 크게 움직이고 있습니다."


def classify_torso(torso_accel: float) -> str:
    if torso_accel < 0.08:
        return "몸통은 비교적 고정되어 있습니다."
    if torso_accel < 0.25:
        return "몸통이 조금 같이 움직이고 있습니다."
    return "몸통 흔들림이 큽니다."


def status_message(motion: MotionSnapshot, tracker: RepTracker, rise_threshold: float) -> str:
    quiet_threshold = max(0.1, rise_threshold * 0.6)
    if tracker.phase == RepPhase.READY and motion.main_accel < quiet_threshold:
        return "시작 자세를 안정적으로 유지 중입니다."
    if tracker.phase == RepPhase.READY:
        return f"{motion.main_side}이 움직이기 시작했습니다."
    if tracker.phase == RepPhase.LIFTING:
        return f"{motion.main_side}을 들어 올리는 동작으로 보입니다."
    if tracker.phase == RepPhase.HOLDING:
        return f"{motion.main_side}을 위에서 유지하고 있는 동작으로 보입니다."
    return f"{motion.main_side}을 다시 내리는 동작으로 보입니다."


def update_rep_tracker(
    tracker: RepTracker,
    motion: MotionSnapshot,
    timestamp_ms: int,
    min_rep_gap_ms: int,
    rise_threshold: float,
    peak_threshold: float,
    return_threshold: float,
) -> Optional[tuple[int, str, float]]:
    delta_from_previous = motion.main_accel - tracker.previous_main_accel

    if tracker.phase == RepPhase.READY:
        enough_gap = (
            tracker.last_rep_ts_ms is None
            or timestamp_ms - tracker.last_rep_ts_ms >= min_rep_gap_ms
        )
        if enough_gap and motion.main_accel >= rise_threshold:
            tracker.phase = RepPhase.LIFTING
            tracker.phase_started_ts_ms = timestamp_ms
            tracker.peak_score = motion.motion_score
            tracker.peak_accel = motion.main_accel
            tracker.falling_frames = 0
            tracker.previous_main_accel = motion.main_accel
        return None

    if tracker.phase == RepPhase.LIFTING:
        tracker.peak_score = max(tracker.peak_score, motion.motion_score)
        tracker.peak_accel = max(tracker.peak_accel, motion.main_accel)
        if motion.main_accel >= peak_threshold:
            tracker.phase = RepPhase.HOLDING
            tracker.falling_frames = 0
        elif motion.main_accel < rise_threshold * 0.6:
            tracker.phase = RepPhase.READY
            tracker.phase_started_ts_ms = None
            tracker.peak_score = 0.0
            tracker.peak_accel = 0.0
            tracker.falling_frames = 0
        tracker.previous_main_accel = motion.main_accel
        return None

    if tracker.phase == RepPhase.HOLDING:
        tracker.peak_score = max(tracker.peak_score, motion.motion_score)
        tracker.peak_accel = max(tracker.peak_accel, motion.main_accel)
        if delta_from_previous < -0.03:
            tracker.falling_frames += 1
        else:
            tracker.falling_frames = 0
        if tracker.falling_frames >= 2:
            tracker.phase = RepPhase.LOWERING
        tracker.previous_main_accel = motion.main_accel
        return None

    tracker.peak_score = max(tracker.peak_score, motion.motion_score)
    tracker.peak_accel = max(tracker.peak_accel, motion.main_accel)
    if motion.main_accel <= return_threshold:
        duration_ms = 0
        if tracker.phase_started_ts_ms is not None:
            duration_ms = timestamp_ms - tracker.phase_started_ts_ms
        duration_sec = max(duration_ms, 0) / 1000.0
        tracker.rep_count += 1
        tracker.last_rep_ts_ms = timestamp_ms
        speed = classify_speed(duration_sec)
        completed_rep = tracker.rep_count
        tracker.phase = RepPhase.READY
        tracker.phase_started_ts_ms = None
        tracker.peak_score = 0.0
        tracker.peak_accel = 0.0
        tracker.falling_frames = 0
        tracker.previous_main_accel = motion.main_accel
        return completed_rep, speed, duration_sec
    tracker.previous_main_accel = motion.main_accel
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read ESP32 frames and explain IMU-only rep inference in Korean."
    )
    parser.add_argument("--port", default="/dev/ttyUSB0", help="Serial port path")
    parser.add_argument("--baud", type=int, default=115200, help="Serial baud rate")
    parser.add_argument(
        "--calibration-frames",
        type=int,
        default=80,
        help="Number of quiet frames used to capture the start pose baseline.",
    )
    parser.add_argument(
        "--rise-threshold",
        type=float,
        default=0.35,
        help="Main arm accel delta threshold to start a rep.",
    )
    parser.add_argument(
        "--peak-threshold",
        type=float,
        default=0.85,
        help="Main arm accel delta threshold to treat the lift as having reached the top.",
    )
    parser.add_argument(
        "--return-threshold",
        type=float,
        default=0.18,
        help="Main arm accel delta threshold to consider the arm returned to the start pose.",
    )
    parser.add_argument(
        "--min-rep-gap-ms",
        type=int,
        default=450,
        help="Minimum gap between consecutive inferred reps.",
    )
    parser.add_argument(
        "--status-every",
        type=int,
        default=10,
        help="Print a live status line every N valid frames.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ser = serial.Serial(
        port=args.port,
        baudrate=args.baud,
        timeout=1,
        dsrdtr=False,
        rtscts=False,
    )
    ser.dtr = False
    ser.rts = False
    ser.reset_input_buffer()

    print(
        f"[imu-test] {args.port} 연결 완료. "
        f"처음 {args.calibration_frames}프레임 동안 시작 자세를 유지하세요."
    )

    buffer = bytearray()
    baseline_frames: list[DecodedFrame] = []
    baseline: Optional[Baseline] = None
    tracker = RepTracker()
    frame_counter = 0

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
                frame_counter += 1

                if baseline is None:
                    baseline_frames.append(decoded)
                    if len(baseline_frames) >= args.calibration_frames:
                        baseline = build_baseline(baseline_frames)
                        print("[imu-test] 시작 자세 baseline 저장 완료. 이제 팔을 움직여 보세요.")
                    elif len(baseline_frames) % 10 == 0:
                        print(
                            f"[imu-test] 시작 자세 baseline 측정 중... "
                            f"{len(baseline_frames)}/{args.calibration_frames}"
                        )
                    continue

                motion = compute_motion(decoded, baseline)
                rep_event = update_rep_tracker(
                    tracker,
                    motion,
                    decoded.timestamp_ms,
                    args.min_rep_gap_ms,
                    args.rise_threshold,
                    args.peak_threshold,
                    args.return_threshold,
                )

                if rep_event is not None:
                    rep_index, speed, duration_sec = rep_event
                    print(
                        f"[imu-test] {rep_index}회 완료 | 속도: {speed} | "
                        f"동작 시간: {duration_sec:.2f}초 | "
                        f"{classify_balance(motion)}"
                    )

                if frame_counter % args.status_every == 0:
                    print(
                        f"[imu-test] 현재 상태: {status_message(motion, tracker, args.rise_threshold)} | "
                        f"주동작: {motion.main_side} | "
                        f"왼팔 변화량 {motion.left_accel:.3f} | "
                        f"오른팔 변화량 {motion.right_accel:.3f} | "
                        f"좌우 차이 {motion.symmetry_gap:.3f} | "
                        f"{classify_torso(motion.torso_accel)} | "
                        f"누적 횟수 {tracker.rep_count}회"
                    )
    except KeyboardInterrupt:
        print(f"\n[imu-test] 종료합니다. 최종 추정 횟수: {tracker.rep_count}회")
        return 130
    finally:
        ser.close()


if __name__ == "__main__":
    raise SystemExit(main())
