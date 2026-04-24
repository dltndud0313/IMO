#!/usr/bin/env python3
"""ESP32 v2 binary sensor frame decoder for live serial streams."""

from __future__ import annotations

import argparse
import struct
import sys
from typing import Optional

import serial


FRAME_SIZE = 38
MAGIC = b"ME"
EXPECTED_VERSION = 2
EXPECTED_PACKET_TYPE = 1
EXPECTED_PAYLOAD_LEN = 30
EMG_SCALE = 1000.0
ACCEL_SCALE = 1000.0
GYRO_SCALE = 100.0
CRC_POLY = 0x1021
CRC_INIT = 0xFFFF

STATE_NAMES = {
    0: "IDLE",
    1: "CALIBRATION_REST",
    2: "CALIBRATION_MVC",
    3: "READY",
    4: "STREAMING",
    5: "ERROR",
}


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


def decode_frame(frame: bytes) -> Optional[str]:
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
    emg1, emg2, emg3, acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z = struct.unpack_from("<9h", frame, 14)
    state_code = frame[32]
    flags = frame[33]
    rep_index = struct.unpack_from("<h", frame, 34)[0]

    state_name = STATE_NAMES.get(state_code, f"UNKNOWN({state_code})")
    rep_index_text = "None" if rep_index == -1 else str(rep_index)

    return (
        f"seq={seq} ts={timestamp_ms} "
        f"emg=({emg1/EMG_SCALE:.3f},{emg2/EMG_SCALE:.3f},{emg3/EMG_SCALE:.3f}) "
        f"acc=({acc_x/ACCEL_SCALE:.3f},{acc_y/ACCEL_SCALE:.3f},{acc_z/ACCEL_SCALE:.3f}) "
        f"gyro=({gyro_x/GYRO_SCALE:.3f},{gyro_y/GYRO_SCALE:.3f},{gyro_z/GYRO_SCALE:.3f}) "
        f"state={state_name} flags={flags} rep_index={rep_index_text}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Decode ESP32 BINARY_V2 sensor frames from a serial port.")
    parser.add_argument("--port", default="/dev/ttyUSB0", help="Serial port path")
    parser.add_argument("--baud", type=int, default=115200, help="Serial baud rate")
    parser.add_argument("--max-frames", type=int, default=0, help="Stop after N valid frames, 0 means unlimited")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ser = serial.Serial(args.port, args.baud, timeout=1)
    buffer = bytearray()
    decoded_frames = 0

    try:
        while True:
            chunk = ser.read(256)
            if not chunk:
                continue
            buffer.extend(chunk)

            while True:
                start = buffer.find(MAGIC)
                if start < 0:
                    if len(buffer) > 2:
                        del buffer[:-2]
                    break

                if len(buffer) - start < FRAME_SIZE:
                    if start > 0:
                        del buffer[:start]
                    break

                frame = bytes(buffer[start:start + FRAME_SIZE])
                del buffer[:start + FRAME_SIZE]

                decoded = decode_frame(frame)
                if decoded is None:
                    continue

                print(decoded)
                sys.stdout.flush()

                decoded_frames += 1
                if args.max_frames > 0 and decoded_frames >= args.max_frames:
                    return 0
    except KeyboardInterrupt:
        return 130
    finally:
        ser.close()


if __name__ == "__main__":
    raise SystemExit(main())
