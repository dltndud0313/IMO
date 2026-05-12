#!/usr/bin/env python3
"""Save ESP32 BINARY_V2 frames to a JSONL session log on Raspberry Pi."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import BinaryIO, Optional, TextIO

try:
    import serial
except ModuleNotFoundError:
    serial = None

from esp32_serial_receiver import FRAME_SIZE, MAGIC, STATE_NAMES, DecodedFrame, decode_frame


@dataclass(frozen=True)
class SessionMeta:
    type: str
    created_at: str
    session_mode: str
    exercise: str
    source: str
    port: str
    baud: int
    note: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Save ESP32 BINARY_V2 frames to a JSONL file."
    )
    parser.add_argument("--port", default="/dev/ttyUSB0", help="ESP32 serial port path")
    parser.add_argument("--baud", type=int, default=115200, help="ESP32 serial baud rate")
    parser.add_argument(
        "--exercise",
        default="bicep_curl",
        help="Exercise label written into the saved JSONL records",
    )
    parser.add_argument(
        "--output",
        default="",
        help="Output JSONL path. Default: device/raspberry-pi/logs/<exercise>_<timestamp>.jsonl",
    )
    parser.add_argument(
        "--note",
        default="",
        help="Optional note stored in the session metadata line",
    )
    parser.add_argument(
        "--input-file",
        default="",
        help="Read raw BINARY_V2 bytes from a file path or '-' for stdin instead of serial.",
    )
    parser.add_argument(
        "--max-frames",
        type=int,
        default=0,
        help="Stop after N valid frames. 0 means unlimited until Ctrl+C.",
    )
    parser.add_argument(
        "--print-every",
        type=int,
        default=25,
        help="Print one progress line every N saved frames. 0 disables progress output.",
    )
    return parser.parse_args()


def build_default_output_path(exercise: str) -> Path:
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    logs_dir = Path(__file__).with_name("logs")
    return logs_dir / f"{exercise}_{timestamp}.jsonl"


def open_input_stream(args: argparse.Namespace) -> tuple[BinaryIO, bool, str]:
    if args.input_file:
        if args.input_file == "-":
            return sys.stdin.buffer, False, "stdin"
        path = Path(args.input_file)
        return path.open("rb"), True, str(path)

    if serial is None:
        raise SystemExit("pyserial이 필요합니다. `pip install pyserial` 후 다시 실행하세요.")

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
    return ser, True, args.port


def write_jsonl_line(handle: TextIO, payload: dict) -> None:
    handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
    handle.flush()


def frame_to_record(frame: DecodedFrame, exercise: str) -> dict:
    imus = []
    for index, (accel, gyro) in enumerate(zip(frame.imu_accels, frame.imu_gyros), start=1):
        imus.append(
            {
                "index": index,
                "accel": list(accel),
                "gyro": list(gyro),
            }
        )

    return {
        "type": "sensor_frame",
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "exercise": exercise,
        "source": "esp32",
        "seq": frame.seq,
        "timestamp_ms": frame.timestamp_ms,
        "state_code": frame.state_code,
        "state": STATE_NAMES.get(frame.state_code, f"UNKNOWN({frame.state_code})"),
        "flags": frame.flags,
        "rep_index": frame.rep_index,
        "emg": list(frame.emg),
        "imus": imus,
    }


def format_emg(frame: DecodedFrame) -> str:
    return (
        f"({frame.emg[0]:.3f},"
        f"{frame.emg[1]:.3f},"
        f"{frame.emg[2]:.3f},"
        f"{frame.emg[3]:.3f})"
    )


def main() -> int:
    args = parse_args()
    output_path = Path(args.output) if args.output else build_default_output_path(args.exercise)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    input_stream, close_input, input_label = open_input_stream(args)
    saved_count = 0
    buffer = bytearray()

    with output_path.open("w", encoding="utf-8") as handle:
        meta = SessionMeta(
            type="session_meta",
            created_at=datetime.now(timezone.utc).isoformat(),
            session_mode="full_session",
            exercise=args.exercise,
            source="esp32",
            port=input_label,
            baud=args.baud,
            note=args.note,
        )
        write_jsonl_line(handle, asdict(meta))
        print(f"[save_esp_session] output={output_path}")
        print("[save_esp_session] recording full session until Ctrl+C")

        try:
            while True:
                chunk = input_stream.read(256)
                if not chunk:
                    if args.input_file:
                        break
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
                    write_jsonl_line(handle, frame_to_record(decoded, args.exercise))
                    saved_count += 1

                    if args.print_every > 0 and saved_count % args.print_every == 0:
                        print(
                            f"[save_esp_session] saved={saved_count} "
                            f"seq={decoded.seq} ts={decoded.timestamp_ms} "
                            f"rep_index={decoded.rep_index} emg={format_emg(decoded)}"
                        )

                    if args.max_frames > 0 and saved_count >= args.max_frames:
                        break

                if args.max_frames > 0 and saved_count >= args.max_frames:
                    break
        except KeyboardInterrupt:
            print("[save_esp_session] interrupted by user")
        finally:
            if close_input:
                input_stream.close()
            write_jsonl_line(
                handle,
                {
                    "type": "session_end",
                    "ended_at": datetime.now(timezone.utc).isoformat(),
                    "exercise": args.exercise,
                    "source": "esp32",
                    "total_frames": saved_count,
                },
            )

    print(f"[save_esp_session] done frames={saved_count} file={output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
