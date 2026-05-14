#!/usr/bin/env python3
"""Generate deterministic mock BINARY_V2 frames for Pi validation."""

from __future__ import annotations

import argparse
import math
import struct
import sys
import time
from typing import Iterable

from mock_esp32_serial_receiver import (
    CRC_INIT,
    CRC_POLY,
    EXPECTED_MAGIC,
    EXPECTED_PACKET_TYPE,
    EXPECTED_PAYLOAD_LEN,
    EXPECTED_VERSION,
)


SAMPLE_INTERVAL_MS = 20
STATE_STREAMING = 1
FLAG_IS_MOCK = 0x01
FLAG_IMU_READY = 0x02
FLAG_MOTION = 0x04


def crc16_ccitt_false(data: bytes) -> int:
    crc = CRC_INIT
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ CRC_POLY) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def encode_frame(
    *,
    seq: int,
    timestamp_ms: int,
    emg: tuple[float, float, float, float],
    imu_accels: tuple[tuple[float, float, float], ...],
    imu_gyros: tuple[tuple[float, float, float], ...],
    flags: int,
    rep_index: int,
) -> bytes:
    frame = bytearray(64)
    struct.pack_into(
        "<HBBH",
        frame,
        0,
        EXPECTED_MAGIC,
        EXPECTED_VERSION,
        EXPECTED_PACKET_TYPE,
        EXPECTED_PAYLOAD_LEN,
    )
    struct.pack_into("<II", frame, 6, seq, timestamp_ms)
    struct.pack_into("<4h", frame, 14, *(int(round(value * 1000.0)) for value in emg))

    imu_values: list[int] = []
    for imu_index in range(3):
        accel = imu_accels[imu_index]
        gyro = imu_gyros[imu_index]
        imu_values.extend(int(round(value * 1000.0)) for value in accel)
        imu_values.extend(int(round(value * 100.0)) for value in gyro)

    struct.pack_into("<18h", frame, 22, *imu_values)
    frame[58] = STATE_STREAMING
    frame[59] = flags
    struct.pack_into("<h", frame, 60, rep_index)
    struct.pack_into("<H", frame, 62, crc16_ccitt_false(frame[:-2]))
    return bytes(frame)


def build_rest_frame(seq: int, timestamp_ms: int, rep_index: int = -1) -> bytes:
    return encode_frame(
        seq=seq,
        timestamp_ms=timestamp_ms,
        emg=(0.04, 0.04, 0.03, 0.03),
        imu_accels=(
            (0.02, -0.01, 1.00),
            (0.01, 0.00, 1.01),
            (0.00, 0.01, 1.00),
        ),
        imu_gyros=(
            (0.5, 0.2, 0.4),
            (0.4, 0.2, 0.3),
            (0.2, 0.2, 0.2),
        ),
        flags=FLAG_IS_MOCK | FLAG_IMU_READY,
        rep_index=rep_index,
    )


def pushup_emg(progress: float, scenario: str) -> tuple[float, float, float, float]:
    envelope = math.sin(math.pi * progress)
    if scenario == "good":
        return (
            0.10 + 0.55 * envelope,
            0.11 + 0.53 * envelope,
            0.07 + 0.32 * envelope,
            0.08 + 0.30 * envelope,
        )
    if scenario == "imbalance":
        return (
            0.12 + 0.60 * envelope,
            0.08 + 0.32 * envelope,
            0.08 + 0.28 * envelope,
            0.07 + 0.18 * envelope,
        )
    return (
        0.12 + 0.48 * envelope,
        0.12 + 0.46 * envelope,
        0.09 + 0.30 * envelope,
        0.09 + 0.28 * envelope,
    )


def pushup_accel(progress: float, scenario: str) -> tuple[tuple[float, float, float], ...]:
    dip = math.sin(math.pi * progress)
    left_arm = (0.08 + 0.18 * dip, -0.05 - 0.18 * dip, 1.0 - 0.35 * dip)
    right_arm = (0.08 + 0.17 * dip, -0.05 - 0.17 * dip, 1.0 - 0.34 * dip)
    torso = (0.01, 0.01, 1.0)

    if scenario == "imbalance":
        left_arm = (0.12 + 0.34 * dip, -0.05 - 0.24 * dip, 1.0 - 0.42 * dip)
        right_arm = (0.04 + 0.10 * dip, -0.02 - 0.08 * dip, 1.0 - 0.12 * dip)
    elif scenario == "torso":
        torso = (0.18 * dip, 0.02, 1.0 - 0.30 * dip)

    return (left_arm, right_arm, torso)


def pushup_gyro(progress: float, scenario: str, speed_factor: str) -> tuple[tuple[float, float, float], ...]:
    curve = math.sin(math.pi * progress)
    if speed_factor == "fast":
        arm_scale = 95.0
    elif speed_factor == "slow":
        arm_scale = 34.0
    else:
        arm_scale = 62.0

    left = (arm_scale * curve, 3.0 * curve, 2.0 * curve)
    right = (arm_scale * curve * 0.97, 2.5 * curve, 2.0 * curve)
    torso = (1.5 * curve, 0.8 * curve, 0.5 * curve)

    if scenario == "imbalance":
        left = (arm_scale * 1.12 * curve, 4.0 * curve, 2.5 * curve)
        right = (arm_scale * 0.46 * curve, 1.2 * curve, 0.8 * curve)
    elif scenario == "torso":
        torso = (18.0 * curve, 6.0 * curve, 3.5 * curve)

    return (left, right, torso)


def build_pushup_stream(
    reps: int,
    scenario: str,
    speed: str,
) -> Iterable[bytes]:
    seq = 0
    timestamp_ms = 0

    for _ in range(110):
        yield build_rest_frame(seq, timestamp_ms)
        seq += 1
        timestamp_ms += SAMPLE_INTERVAL_MS

    if speed == "fast":
        frames_per_rep = 40
    elif speed == "slow":
        frames_per_rep = 130
    else:
        frames_per_rep = 75

    for rep in range(reps):
        for frame_index in range(frames_per_rep):
            progress = frame_index / max(1, frames_per_rep - 1)
            moving = 0.08 < progress < 0.92
            flags = FLAG_IS_MOCK | FLAG_IMU_READY | (FLAG_MOTION if moving else 0)
            rep_index = rep if frame_index == frames_per_rep - 1 else -1
            yield encode_frame(
                seq=seq,
                timestamp_ms=timestamp_ms,
                emg=pushup_emg(progress, scenario),
                imu_accels=pushup_accel(progress, scenario),
                imu_gyros=pushup_gyro(progress, scenario, speed),
                flags=flags,
                rep_index=rep_index,
            )
            seq += 1
            timestamp_ms += SAMPLE_INTERVAL_MS

        for _ in range(10):
            yield build_rest_frame(seq, timestamp_ms, rep_index=rep)
            seq += 1
            timestamp_ms += SAMPLE_INTERVAL_MS


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Emit deterministic mock BINARY_V2 frames for HUD validation."
    )
    parser.add_argument(
        "--exercise",
        default="pushup",
        choices=["pushup"],
        help="Exercise scenario to emit.",
    )
    parser.add_argument(
        "--scenario",
        default="good",
        choices=["good", "imbalance", "torso"],
        help="Behavior profile to validate posture and activation handling.",
    )
    parser.add_argument(
        "--speed",
        default="normal",
        choices=["slow", "normal", "fast"],
        help="Rep speed profile.",
    )
    parser.add_argument("--reps", type=int, default=6, help="Number of reps to emit.")
    parser.add_argument(
        "--realtime",
        action="store_true",
        help="Emit frames in real time using the sample interval.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.exercise != "pushup":
        raise SystemExit("현재는 pushup 시나리오만 지원합니다.")

    for frame in build_pushup_stream(args.reps, args.scenario, args.speed):
        sys.stdout.buffer.write(frame)
        sys.stdout.buffer.flush()
        if args.realtime:
            time.sleep(SAMPLE_INTERVAL_MS / 1000.0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
