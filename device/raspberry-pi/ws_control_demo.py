#!/usr/bin/env python3
"""Send demo control messages to the Pi WebSocket bridge."""

from __future__ import annotations

import argparse
import asyncio
import json
import uuid

try:
    from websockets.asyncio.client import connect
except ModuleNotFoundError as exc:
    raise SystemExit(
        "websockets 패키지가 필요합니다. `pip install websockets` 후 다시 실행하세요."
    ) from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Demo WebSocket control sender for Pi bridge.")
    parser.add_argument("--url", default="ws://127.0.0.1:8765", help="Bridge websocket URL")
    parser.add_argument(
        "--exercise",
        default="pushup",
        choices=["pushup", "bicep_curl", "lateral_raise"],
        help="Exercise type",
    )
    parser.add_argument("--sets", type=int, default=3, help="Set count")
    parser.add_argument("--reps", default="12,12,10", help="Comma-separated target reps per set")
    parser.add_argument("--rest-sec", type=int, default=60, help="Rest seconds")
    parser.add_argument(
        "--flow",
        default="full",
        choices=["plan", "attach", "calibrate", "full", "pause", "resume", "stop", "emergency"],
        help="How many steps to send",
    )
    return parser.parse_args()


def build_message(msg_type: str, payload: dict) -> str:
    return json.dumps(
        {
            "type": msg_type,
            "payload": payload,
            "requestId": str(uuid.uuid4()),
        }
    )


async def main() -> int:
    args = parse_args()
    reps = [int(value.strip()) for value in args.reps.split(",") if value.strip()]

    async with connect(args.url) as websocket:
        if args.flow in {"plan", "attach", "calibrate", "full"}:
            plan_message = build_message(
                "submit_workout_plan",
                {
                    "exercise_type": args.exercise,
                    "set_count": args.sets,
                    "target_reps_per_set": reps,
                    "rest_sec": args.rest_sec,
                },
            )
            await websocket.send(plan_message)
            print(f"sent: submit_workout_plan {args.exercise}")

        if args.flow in {"attach", "calibrate", "full"}:
            await asyncio.sleep(0.5)
            await websocket.send(build_message("sensors_attached", {}))
            print("sent: sensors_attached")

        if args.flow in {"calibrate", "full"}:
            await asyncio.sleep(0.5)
            await websocket.send(
                build_message(
                    "start_calibration",
                    {"exercise_type": args.exercise},
                )
            )
            print("sent: start_calibration")

        if args.flow == "pause":
            await websocket.send(build_message("pause_workout", {"reason": "demo"}))
            print("sent: pause_workout")

        if args.flow == "resume":
            await websocket.send(build_message("resume_workout", {"reason": "demo"}))
            print("sent: resume_workout")

        if args.flow == "stop":
            await websocket.send(build_message("stop_workout", {"reason": "demo"}))
            print("sent: stop_workout")

        if args.flow == "emergency":
            await websocket.send(build_message("emergency_stop", {"reason": "demo"}))
            print("sent: emergency_stop")

        for _ in range(12):
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                print(f"recv: {response}")
            except asyncio.TimeoutError:
                break

    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
