#!/usr/bin/env python3
"""Bridge ESP32 serial frames to app-facing WebSocket messages and glass UI."""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import sys
import threading
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Optional

try:
    import serial
except ModuleNotFoundError:
    serial = None

try:
    from websockets.asyncio.server import ServerConnection, serve
except ModuleNotFoundError as exc:
    raise SystemExit(
        "websockets 패키지가 필요합니다. `pip install websockets` 후 다시 실행하세요."
    ) from exc

from mock_esp32_serial_receiver import (
    FRAME_SIZE,
    MAGIC,
    STATE_NAMES,
    DecodedFrame,
    decode_frame,
)
from glass_metrics import SENSOR_CONFIGS, analyze_frame, build_phase_result, build_waiting_result


UI_DIR = Path(__file__).with_name("glass-ui")
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
    emg_activation_threshold: list[float] = field(default_factory=lambda: [0.05] * 4)
    imu_rest_accel: list[list[float]] = field(
        default_factory=lambda: [[0.0, 0.0, 0.0] for _ in range(3)]
    )
    imu_rest_gyro: list[list[float]] = field(
        default_factory=lambda: [[0.0, 0.0, 0.0] for _ in range(3)]
    )
    ready: bool = False


class BridgeState:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._esp32_connected = False
        self._glass_connected = False
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
        self._last_device_rep_index: Optional[int] = None
        self._current_speed_label = "분석 중"
        self._calibration_data = CalibrationData()
        self._calibration_frames: list[DecodedFrame] = []
        self._calibration_collecting = False

    def update_frame(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        with self._lock:
            events: list[dict[str, Any]] = []
            self._esp32_connected = True
            if self._phase == "calibrating" and not self._calibration_collecting:
                # 캘리브레이션 종료 후 앱의 start_workout 요청 전까지 monitoring 진입을 보류한다.
                self._phase = "awaiting_workout_start"
            events.extend(self._maybe_finish_rest_locked())
            if frame.rep_index is not None:
                events.extend(self._apply_device_rep_index_locked(frame))
            else:
                events.extend(self._maybe_increment_rep(frame))
            return events

    def tick(self) -> list[dict[str, Any]]:
        with self._lock:
            return self._maybe_finish_rest_locked()

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
            self._last_device_rep_index = None
            self._current_speed_label = "분석 중"
            self._calibration_data = CalibrationData(exercise_type=exercise_type)
            self._calibration_frames = []
            self._calibration_collecting = False

    def mark_sensors_attached(self) -> None:
        with self._lock:
            self._sensors_attached = True
            if self._phase == "ready_for_calibration":
                self._phase = "sensors_ready"

    def start_calibration_collection(self) -> None:
        with self._lock:
            self._calibration_frames = []
            self._calibration_collecting = True
            self._calibration_data.ready = False
            self._phase = "calibrating"

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
        # 앱의 start_workout 요청을 받아 monitoring 으로 진입.
        with self._lock:
            if self._phase != "awaiting_workout_start":
                return False
            self._phase = "monitoring"
            return True

    def mark_completed(self) -> None:
        with self._lock:
            self._phase = "completed"
            self._rest_deadline_monotonic = None

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
                current_speed_label=self._current_speed_label,
                sensors_attached=self._sensors_attached,
            )

    def calibration_snapshot(self) -> CalibrationData:
        with self._lock:
            return CalibrationData(
                exercise_type=self._calibration_data.exercise_type,
                emg_rest_baseline=list(self._calibration_data.emg_rest_baseline),
                emg_activation_threshold=list(self._calibration_data.emg_activation_threshold),
                imu_rest_accel=[list(v) for v in self._calibration_data.imu_rest_accel],
                imu_rest_gyro=[list(v) for v in self._calibration_data.imu_rest_gyro],
                ready=self._calibration_data.ready,
            )

    def _apply_device_rep_index_locked(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        events: list[dict[str, Any]] = []
        if self._last_device_rep_index is None:
            self._last_device_rep_index = frame.rep_index
            if self._phase == "monitoring":
                self._current_rep = frame.rep_index + 1
                self._update_speed_label_locked(frame.timestamp_ms)
                self._last_rep_timestamp_ms = frame.timestamp_ms
                return self._maybe_advance_workout_locked(frame.timestamp_ms)
            return events

        if frame.rep_index < self._last_device_rep_index:
            self._last_device_rep_index = frame.rep_index
            if self._phase == "monitoring":
                self._current_rep = frame.rep_index + 1
                self._update_speed_label_locked(frame.timestamp_ms)
                self._last_rep_timestamp_ms = frame.timestamp_ms
                return self._maybe_advance_workout_locked(frame.timestamp_ms)
            return events

        if self._phase != "monitoring":
            self._last_device_rep_index = frame.rep_index
            return events

        delta = frame.rep_index - self._last_device_rep_index
        self._last_device_rep_index = frame.rep_index
        if delta <= 0:
            return events

        next_rep = 0 if self._current_rep is None else self._current_rep
        self._current_rep = next_rep + delta
        self._update_speed_label_locked(frame.timestamp_ms)
        self._last_rep_timestamp_ms = frame.timestamp_ms
        return self._maybe_advance_workout_locked(frame.timestamp_ms)

    def _maybe_increment_rep(self, frame: DecodedFrame) -> list[dict[str, Any]]:
        if self._phase != "monitoring":
            return []

        motion_detected = bool(frame.flags & 0x04)
        primary_emg = max(frame.emg[0], frame.emg[1], frame.emg[2], frame.emg[3])
        imu_gyro = frame.imu_gyros[0] if frame.imu_gyros else (0.0, 0.0, 0.0)
        gyro_norm = math.fabs(imu_gyro[0]) + math.fabs(imu_gyro[1]) + math.fabs(imu_gyro[2])
        active_now = motion_detected and primary_emg >= 0.06 and gyro_norm >= 2.2

        if active_now and not self._motion_active:
            enough_gap = (
                self._last_rep_timestamp_ms is None
                or frame.timestamp_ms - self._last_rep_timestamp_ms >= 700
            )
            if enough_gap:
                self._current_rep = 1 if self._current_rep is None else self._current_rep + 1
                self._update_speed_label_locked(frame.timestamp_ms)
                self._last_rep_timestamp_ms = frame.timestamp_ms
                self._motion_active = active_now
                return self._maybe_advance_workout_locked(frame.timestamp_ms)
        self._motion_active = active_now
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
        self._current_speed_label = "분석 중"
        return [
            {
                "event": "rest_finished",
                "current_set_index": self._current_set_index + 1,
            }
        ]

    def _maybe_advance_workout_locked(self, timestamp_ms: int) -> list[dict[str, Any]]:
        target_rep = self._current_target_rep_locked()
        if target_rep is None or self._current_rep is None or self._current_rep < target_rep:
            return []

        actual_rep = self._current_rep
        completed_set_index = self._current_set_index + 1
        events = [
            {
                "event": "set_completed",
                "completed_set_index": completed_set_index,
                "actual_rep": actual_rep,
                "target_rep": target_rep,
                "timestamp_ms": timestamp_ms,
            }
        ]

        if completed_set_index >= self._set_count:
            self._phase = "completed"
            self._rest_deadline_monotonic = None
            events.append(
                {
                    "event": "workout_completed",
                    "completed_sets": self._set_count,
                    "timestamp_ms": timestamp_ms,
                }
            )
            return events

        self._current_set_index += 1
        self._current_rep = 0
        self._phase = "resting"
        self._rest_deadline_monotonic = time.monotonic() + self._rest_sec
        events.append(
            {
                "event": "rest_started",
                "next_set_index": self._current_set_index + 1,
                "rest_sec": self._rest_sec,
            }
        )
        return events

    def maybe_collect_calibration_frame(self, frame: DecodedFrame) -> bool:
        with self._lock:
            if not self._calibration_collecting:
                return False

            self._calibration_frames.append(frame)

            if len(self._calibration_frames) < 100:
                return False

            self._finalize_calibration_locked()
            return True

    def _finalize_calibration_locked(self) -> None:
        frames = self._calibration_frames
        if not frames:
            return

        emg_sums = [0.0, 0.0, 0.0, 0.0]
        imu_acc_sums = [[0.0, 0.0, 0.0] for _ in range(3)]
        imu_gyro_sums = [[0.0, 0.0, 0.0] for _ in range(3)]

        for frame in frames:
            for channel_index in range(4):
                emg_sums[channel_index] += frame.emg[channel_index]
            for imu_index in range(3):
                if imu_index < len(frame.imu_accels):
                    for axis in range(3):
                        imu_acc_sums[imu_index][axis] += frame.imu_accels[imu_index][axis]
                if imu_index < len(frame.imu_gyros):
                    for axis in range(3):
                        imu_gyro_sums[imu_index][axis] += frame.imu_gyros[imu_index][axis]

        frame_count = float(len(frames))
        self._calibration_data.emg_rest_baseline = [value / frame_count for value in emg_sums]
        self._calibration_data.emg_activation_threshold = [
            baseline + 0.03 for baseline in self._calibration_data.emg_rest_baseline
        ]
        self._calibration_data.imu_rest_accel = [
            [value / frame_count for value in imu_values] for imu_values in imu_acc_sums
        ]
        self._calibration_data.imu_rest_gyro = [
            [value / frame_count for value in imu_values] for imu_values in imu_gyro_sums
        ]
        self._calibration_data.ready = True

        self._calibration_collecting = False
        self._calibration_frames = []
        # 앱의 start_workout 입력 전까지 monitoring 으로 자동 진입하지 않는다.
        self._phase = "awaiting_workout_start"
        self._current_rep = 0
        self._current_speed_label = "분석 중"

    def _update_speed_label_locked(self, timestamp_ms: int) -> None:
        if self._last_rep_timestamp_ms is None:
            self._current_speed_label = "분석 중"
            return

        gap_ms = max(0, timestamp_ms - self._last_rep_timestamp_ms)
        if gap_ms < 1200:
            self._current_speed_label = "빠름"
        elif gap_ms < 2600:
            self._current_speed_label = "적정"
        else:
            self._current_speed_label = "느림"

    @staticmethod
    def _phase_label(phase: str) -> str:
        return {
            "idle": "운동 선택 대기",
            "ready_for_calibration": "센서 부착 대기",
            "sensors_ready": "캘리브레이션 준비",
            "calibrating": "캘리브레이션 진행 중",
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
            "activation_level": result.activation_level,
            "usage_text": result.usage_text,
            "usage_tone": result.usage_tone,
            "pose_badge": result.pose_badge,
            "pose_title": result.pose_title,
            "pose_detail": result.pose_detail,
            "pose_tone": result.pose_tone,
            "sensors": sensors,
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
) -> dict[str, Any]:
    payload = {
        "status": status,
        "message": message,
    }
    if calibration_summary is not None:
        payload["calibration_summary"] = calibration_summary

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


def build_error_message(code: str, message: str) -> dict[str, Any]:
    return wrap_message(
        "error",
        {
            "code": code,
            "message": message,
        },
    )


class SensorBridge:
    def __init__(
        self,
        serial_port: str,
        baud_rate: int,
        input_file: str = "",
        *,
        auto_exercise: str = "",
        auto_sets: int = 0,
        auto_reps: Optional[list[int]] = None,
        auto_rest_sec: int = 0,
        auto_start: bool = False,
    ) -> None:
        self._serial_port = serial_port
        self._baud_rate = baud_rate
        self._input_file = input_file
        self._state = BridgeState()
        self._clients: set[ServerConnection] = set()
        self._queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._last_frame: Optional[DecodedFrame] = None
        self._auto_exercise = auto_exercise
        self._auto_sets = auto_sets
        self._auto_reps = auto_reps or []
        self._auto_rest_sec = auto_rest_sec
        self._auto_start = auto_start

    async def run(
        self,
        ws_host: str,
        ws_port: int,
        ui_host: str,
        ui_port: int,
    ) -> None:
        self._loop = asyncio.get_running_loop()
        self._start_ui_http_server(ui_host, ui_port)
        self._bootstrap_mock_session()

        worker = threading.Thread(target=self._serial_reader_main, daemon=True)
        worker.start()

        async with serve(self._handle_client, ws_host, ws_port):
            print(f"[bridge] websocket listening: ws://{ws_host}:{ws_port}")
            print(f"[bridge] glass ui: http://{ui_host}:{ui_port}")
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
        await websocket.send(
            json.dumps(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
        )
        try:
            async for raw_message in websocket:
                await self._handle_client_message(websocket, raw_message)
        finally:
            self._clients.discard(websocket)
            self._state.set_glass_connected(bool(self._clients))
            self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))

    def _bootstrap_mock_session(self) -> None:
        if not self._auto_exercise:
            return

        self._state.set_workout_plan(
            exercise_type=self._auto_exercise,
            set_count=self._auto_sets,
            target_reps_per_set=list(self._auto_reps),
            rest_sec=self._auto_rest_sec,
        )
        self._state.mark_sensors_attached()
        if self._auto_start:
            self._state.start_calibration_collection()

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
                self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
                self._emit_from_thread(
                    build_glass_display_data(
                        self._state.session_snapshot(),
                        self._last_frame,
                        self._state.calibration_snapshot(),
                    )
                )

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
            self._emit_from_thread(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
            return

        if msg_type == "start_calibration":
            if session.phase != "sensors_ready":
                await websocket.send(
                    json.dumps(
                        build_error_message(
                            "INVALID_STATE",
                            "start_calibration must be sent after sensors_attached.",
                        )
                    )
                )
                return
            self._state.start_calibration_collection()
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
            await websocket.send(
                json.dumps(
                    build_calibration_status(
                        status="started",
                        message="센서 기준값 측정을 시작합니다.",
                        request_id=request_id,
                    )
                )
            )
            return

        if msg_type == "start_workout":
            if session.exercise_type is None or session.phase != "awaiting_workout_start":
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
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
            return

        if msg_type == "pause_workout":
            if session.phase not in {"monitoring", "resting", "calibrating"}:
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
            self._emit_from_thread(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
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
            self._emit_from_thread(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
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
            self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
            self._emit_from_thread(
                build_glass_display_data(
                    self._state.session_snapshot(),
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
            self._emit_from_thread(
                build_workout_event(
                    "workout_stopped" if msg_type == "stop_workout" else "emergency_stopped",
                    self._state.session_snapshot(),
                    {"request_id": request_id},
                )
            )
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
            workout_events = self._state.tick()
            if not workout_events:
                continue

            current_session = self._state.session_snapshot()
            self._emit_from_thread(build_glass_session_state(current_session))
            self._emit_from_thread(
                build_glass_display_data(
                    current_session,
                    self._last_frame,
                    self._state.calibration_snapshot(),
                )
            )
            for workout_event in workout_events:
                event_type = str(workout_event.get("event", "unknown"))
                details = {key: value for key, value in workout_event.items() if key != "event"}
                self._emit_from_thread(
                    build_workout_event(
                        event_type,
                        self._state.session_snapshot(),
                        details,
                    )
                )

    def _emit_from_thread(self, message: dict[str, Any]) -> None:
        if self._loop is None:
            return
        self._loop.call_soon_threadsafe(self._queue.put_nowait, message)

    def _serial_reader_main(self) -> None:
        while True:
            try:
                self._serial_reader_once()
            except Exception as exc:
                self._state.mark_esp32_disconnected()
                self._emit_from_thread(
                    build_error_message(
                        "ESP32_INPUT_ERROR",
                        f"Input connection failed: {exc}",
                    )
                )
                self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))
                threading.Event().wait(1.0)

    def _serial_reader_once(self) -> None:
        if self._input_file:
            if self._input_file == "-":
                stream = sys.stdin.buffer
                close_stream = False
            else:
                stream = Path(self._input_file).open("rb")
                close_stream = True
        else:
            if serial is None:
                raise RuntimeError("pyserial이 필요합니다. `pip install pyserial` 후 다시 실행하세요.")
            stream = serial.Serial(
                port=self._serial_port,
                baudrate=self._baud_rate,
                timeout=1,
                dsrdtr=False,
                rtscts=False,
            )
            stream.dtr = False
            stream.rts = False
            stream.reset_input_buffer()
            close_stream = True

        self._state.mark_esp32_disconnected()
        self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))

        buffer = bytearray()
        try:
            while True:
                chunk = stream.read(256)
                if not chunk:
                    if self._input_file:
                        return
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
                    first_connected = not self._state.connection_snapshot().esp32_connected
                    previous_phase = self._state.session_snapshot().phase
                    workout_events = self._state.update_frame(decoded)
                    self._last_frame = decoded
                    calibration_completed = self._state.maybe_collect_calibration_frame(decoded)
                    if first_connected:
                        self._emit_from_thread(build_connection_status(self._state.connection_snapshot()))
                    current_session = self._state.session_snapshot()
                    if previous_phase != current_session.phase:
                        self._emit_from_thread(build_glass_session_state(current_session))
                    self._emit_from_thread(
                        build_glass_display_data(
                            current_session,
                            decoded,
                            self._state.calibration_snapshot(),
                        )
                    )
                    self._emit_from_thread(build_sensor_frame_message(decoded))
                    for workout_event in workout_events:
                        event_type = str(workout_event.get("event", "unknown"))
                        details = {key: value for key, value in workout_event.items() if key != "event"}
                        self._emit_from_thread(
                            build_workout_event(
                                event_type,
                                self._state.session_snapshot(),
                                details,
                            )
                        )
                    if calibration_completed:
                        calibration = self._state.calibration_snapshot()
                        self._emit_from_thread(
                            build_calibration_status(
                                status="success",
                                message="기준값 측정 완료",
                                calibration_summary={
                                    "emg_rest_baseline": calibration.emg_rest_baseline,
                                    "emg_activation_threshold": calibration.emg_activation_threshold,
                                    "imu_rest_accel": calibration.imu_rest_accel,
                                    "imu_rest_gyro": calibration.imu_rest_gyro,
                                },
                            )
                        )
                        self._emit_from_thread(build_glass_session_state(self._state.session_snapshot()))
                        self._emit_from_thread(
                            build_glass_display_data(
                                self._state.session_snapshot(),
                                decoded,
                                calibration,
                            )
                        )
        finally:
            if close_stream:
                stream.close()
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
    parser.add_argument(
        "--input-file",
        default="",
        help="Read raw BINARY_V2 bytes from a file path or '-' for stdin instead of serial.",
    )
    parser.add_argument("--ws-host", default="0.0.0.0", help="WebSocket bind host")
    parser.add_argument("--ws-port", type=int, default=8765, help="WebSocket bind port")
    parser.add_argument("--ui-host", default="0.0.0.0", help="Glass UI bind host")
    parser.add_argument("--ui-port", type=int, default=8080, help="Glass UI bind port")
    parser.add_argument(
        "--auto-exercise",
        default="",
        choices=["", "pushup", "bicep_curl", "lateral_raise"],
        help="Optionally preload a workout plan for mock validation.",
    )
    parser.add_argument("--auto-sets", type=int, default=3, help="Auto plan set count")
    parser.add_argument(
        "--auto-reps",
        default="12,12,10",
        help="Comma-separated target reps for the auto plan.",
    )
    parser.add_argument("--auto-rest-sec", type=int, default=60, help="Auto plan rest seconds")
    parser.add_argument(
        "--auto-start",
        action="store_true",
        help="Automatically mark sensors attached and start calibration for the mock plan.",
    )
    return parser.parse_args()


async def async_main() -> int:
    args = parse_args()
    auto_reps = [int(value.strip()) for value in args.auto_reps.split(",") if value.strip()]
    bridge = SensorBridge(
        serial_port=args.serial_port,
        baud_rate=args.baud,
        input_file=args.input_file,
        auto_exercise=args.auto_exercise,
        auto_sets=args.auto_sets,
        auto_reps=auto_reps,
        auto_rest_sec=args.auto_rest_sec,
        auto_start=args.auto_start,
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
