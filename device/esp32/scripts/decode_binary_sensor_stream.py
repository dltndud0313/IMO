#!/usr/bin/env python3
"""ESP32 v2 binary sensor frame decoder for live serial streams."""

from __future__ import annotations

import argparse
import struct
import sys
from typing import NamedTuple, Optional

try:
    import serial
except ModuleNotFoundError as exc:
    raise SystemExit(
        "pyserial이 필요합니다. ESP-IDF python env를 활성화하거나 `pip install pyserial` 후 다시 실행하세요."
    ) from exc


FRAME_SIZE = 64
MAGIC = b"ME"
EXPECTED_VERSION = 2
EXPECTED_PACKET_TYPE = 1
EXPECTED_PAYLOAD_LEN = 56
EMG_SCALE = 1000.0
ACCEL_SCALE = 1000.0
GYRO_SCALE = 100.0
CRC_POLY = 0x1021
CRC_INIT = 0xFFFF

STATE_NAMES = {
    0: "IDLE",
    1: "STREAMING",
    2: "ERROR",
}


class DecodedFrame(NamedTuple):
    seq: int
    timestamp_ms: int
    text: str


def crc16_ccitt_false(data: bytes) -> int:
    crc = CRC_INIT
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if (crc & 0x8000) != 0:
                crc = ((crc << 1) ^ CRC_POLY) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def decode_frame(frame: bytes) -> Optional[DecodedFrame]:
    if len(frame) != FRAME_SIZE:
        return None

    magic, version, packet_type, payload_len = struct.unpack_from("<HBBH", frame, 0)
    if magic != 0x454D:
        return None
    if version != EXPECTED_VERSION or packet_type != EXPECTED_PACKET_TYPE or payload_len != EXPECTED_PAYLOAD_LEN:
        return None

    expected_crc = struct.unpack_from("<H", frame, FRAME_SIZE - 2)[0]
    actual_crc = crc16_ccitt_false(frame[:-2])
    if expected_crc != actual_crc:
        return None

    seq, timestamp_ms = struct.unpack_from("<II", frame, 6)
    emg1, emg2, emg3, emg4 = struct.unpack_from("<4h", frame, 14)
    imu_values = struct.unpack_from("<18h", frame, 22)
    state_code = frame[58]
    flags = frame[59]
    rep_index = struct.unpack_from("<h", frame, 60)[0]

    state_name = STATE_NAMES.get(state_code, f"UNKNOWN({state_code})")
    rep_index_text = "None" if rep_index == -1 else str(rep_index)

    imus = []
    for imu_index in range(3):
        base = imu_index * 6
        acc = (
            imu_values[base + 0] / ACCEL_SCALE,
            imu_values[base + 1] / ACCEL_SCALE,
            imu_values[base + 2] / ACCEL_SCALE,
        )
        gyro = (
            imu_values[base + 3] / GYRO_SCALE,
            imu_values[base + 4] / GYRO_SCALE,
            imu_values[base + 5] / GYRO_SCALE,
        )
        imus.append((acc, gyro))

    text = (
        f"seq={seq} ts={timestamp_ms} "
        f"emg=({emg1/EMG_SCALE:.3f},{emg2/EMG_SCALE:.3f},{emg3/EMG_SCALE:.3f},{emg4/EMG_SCALE:.3f}) "
        f"imu1_acc=({imus[0][0][0]:.3f},{imus[0][0][1]:.3f},{imus[0][0][2]:.3f}) "
        f"imu1_gyro=({imus[0][1][0]:.3f},{imus[0][1][1]:.3f},{imus[0][1][2]:.3f}) "
        f"imu2_acc=({imus[1][0][0]:.3f},{imus[1][0][1]:.3f},{imus[1][0][2]:.3f}) "
        f"imu2_gyro=({imus[1][1][0]:.3f},{imus[1][1][1]:.3f},{imus[1][1][2]:.3f}) "
        f"imu3_acc=({imus[2][0][0]:.3f},{imus[2][0][1]:.3f},{imus[2][0][2]:.3f}) "
        f"imu3_gyro=({imus[2][1][0]:.3f},{imus[2][1][1]:.3f},{imus[2][1][2]:.3f}) "
        f"state={state_name} flags={flags} rep_index={rep_index_text}"
    )
    return DecodedFrame(seq=seq, timestamp_ms=timestamp_ms, text=text)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Decode ESP32 BINARY_V2 sensor frames from a serial port.")
    parser.add_argument("--port", default="/dev/ttyUSB0", help="Serial port path")
    parser.add_argument("--baud", type=int, default=115200, help="Serial baud rate")
    parser.add_argument("--max-frames", type=int, default=0, help="Stop after N valid frames, 0 means unlimited")
    parser.add_argument("--show-gaps", action="store_true", help="Print seq/timestamp gaps between decoded frames")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ser = serial.Serial(
        args.port,
        args.baud,
        timeout=1,
        dsrdtr=False,
        rtscts=False,
    )
    # 일부 보드/드라이버는 DTR 토글로 리셋되면서 포트 재열거가 발생한다.
    # 수신 전 DTR/RTS를 내리고 입력 버퍼를 비워 프레임 동기화를 안정화한다.
    ser.dtr = False
    ser.rts = False
    ser.reset_input_buffer()
    buffer = bytearray()
    decoded_frames = 0
    last_seq: Optional[int] = None
    last_timestamp_ms: Optional[int] = None

    try:
        while True:
            chunk = ser.read(256)
            if not chunk:
                continue
            buffer.extend(chunk)

            while len(buffer) >= FRAME_SIZE:
                # 프레임 시작 매직을 먼저 0번 위치로 정렬한다.
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

                frame = bytes(buffer[:FRAME_SIZE])
                decoded = decode_frame(frame)
                if decoded is None:
                    # CRC/버전/길이 불일치 시 1바이트만 밀어 재동기화한다.
                    del buffer[0]
                    continue

                del buffer[:FRAME_SIZE]
                line = decoded.text
                if args.show_gaps and last_seq is not None and last_timestamp_ms is not None:
                    seq_gap = decoded.seq - last_seq
                    ts_gap = decoded.timestamp_ms - last_timestamp_ms
                    line = f"{line} seq_gap={seq_gap} ts_gap_ms={ts_gap}"
                print(line)
                sys.stdout.flush()

                last_seq = decoded.seq
                last_timestamp_ms = decoded.timestamp_ms
                decoded_frames += 1
                if args.max_frames > 0 and decoded_frames >= args.max_frames:
                    return 0
    except KeyboardInterrupt:
        return 130
    finally:
        ser.close()


if __name__ == "__main__":
    raise SystemExit(main())
