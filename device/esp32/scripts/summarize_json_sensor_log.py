#!/usr/bin/env python3
"""ESP32 JSON 센서 로그를 읽어 필드별 통계를 출력한다."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Dict, Iterable, List


NUMERIC_FIELDS = [
    "emg_ch1",
    "emg_ch2",
    "emg_ch3",
    "acc_x",
    "acc_y",
    "acc_z",
    "gyro_x",
    "gyro_y",
    "gyro_z",
]


def load_packets(path: Path) -> List[dict]:
    packets: List[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped.startswith("{"):
            continue
        try:
            packets.append(json.loads(stripped))
        except json.JSONDecodeError:
            continue
    return packets


def mean(values: Iterable[float]) -> float:
    values = list(values)
    if not values:
        return 0.0
    return sum(values) / float(len(values))


def stddev(values: Iterable[float], avg: float) -> float:
    values = list(values)
    if not values:
        return 0.0
    variance = sum((value - avg) ** 2 for value in values) / float(len(values))
    return math.sqrt(variance)


def summarize_field(packets: List[dict], field: str) -> Dict[str, float]:
    values = [float(packet[field]) for packet in packets if field in packet]
    if not values:
        return {
            "count": 0,
            "min": 0.0,
            "max": 0.0,
            "avg": 0.0,
            "stddev": 0.0,
            "range": 0.0,
        }

    avg = mean(values)
    return {
        "count": float(len(values)),
        "min": min(values),
        "max": max(values),
        "avg": avg,
        "stddev": stddev(values, avg),
        "range": max(values) - min(values),
    }


def print_summary(packets: List[dict]) -> None:
    if not packets:
        print("No JSON packets found.")
        return

    first_ts = packets[0].get("timestamp_ms", 0)
    last_ts = packets[-1].get("timestamp_ms", 0)
    duration_ms = int(last_ts) - int(first_ts)

    print(f"packets={len(packets)}")
    print(f"duration_ms={duration_ms}")
    print(f"first_seq={packets[0].get('seq', 'N/A')}")
    print(f"last_seq={packets[-1].get('seq', 'N/A')}")
    print()
    print("field,count,min,max,avg,stddev,range")
    for field in NUMERIC_FIELDS:
        summary = summarize_field(packets, field)
        print(
            f"{field},"
            f"{int(summary['count'])},"
            f"{summary['min']:.4f},"
            f"{summary['max']:.4f},"
            f"{summary['avg']:.4f},"
            f"{summary['stddev']:.4f},"
            f"{summary['range']:.4f}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="ESP32 JSON 센서 로그 통계 요약")
    parser.add_argument("log_path", type=Path, help="JSON 로그 파일 경로")
    args = parser.parse_args()

    packets = load_packets(args.log_path)
    print_summary(packets)


if __name__ == "__main__":
    main()
