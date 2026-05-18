from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel, ConfigDict


# 외부에서 들어오는 페이로드는 명세 §2-2 #9 / API-06 의 snake_case 형식을 그대로 받는다.
# (Pi -> 앱 -> 백엔드 로 전달되는 JSON 이므로 이미 snake_case 로 정착되어 있음)
class CalibrationSummaryBase(BaseModel):
    ch1_mvc: float
    ch2_mvc: float
    ch3_mvc: float


class BalanceSummaryBase(BaseModel):
    enabled: bool
    reason: str
    left_value: Optional[float] = None
    right_value: Optional[float] = None
    diff_value: Optional[float] = None
    balance_label: Optional[str] = None


class SetResultBase(BaseModel):
    set_index: int
    target_reps: int
    actual_reps: int
    compensation_count: int
    avg_speed: str
    started_at: datetime
    ended_at: datetime


class SessionCreate(BaseModel):
    """앱에서 POST /sessions 로 보내는 페이로드.

    user_id 필드는 보안상 받지 않는다 — JWT 의 current_user.id 강제 사용.
    """

    session_id: str
    exercise_type: str
    status: str
    end_reason: str
    started_at: datetime
    ended_at: datetime
    duration_sec: int
    set_count: int
    target_reps_per_set: List[int]
    actual_reps_per_set: List[int]
    rest_sec: int
    total_reps: int
    valid_reps: int
    avg_target_muscle: float
    avg_assist_muscle: float
    avg_compensator: float
    compensation_count: int
    fatigue_onset_set: Optional[int] = None
    fatigue_onset_rep: Optional[int] = None
    comment: Optional[str] = None

    calibration_summary: Optional[CalibrationSummaryBase] = None
    # 단위 계약 (2026-05-18 통일): 활성도 값은 전부 0~100 percent.
    # Pi 가 _build_muscle_map_locked 에서 *100 적용해서 송신, 백엔드는 그대로 저장/응답.
    # calibration_summary.ch*_mvc 는 정규화 분모(MVC 기준값)라 raw EMG 값 그대로.
    muscle_map: Optional[Dict[str, float]] = None  # {"left_chest": 68.0, ...}
    balance_summary: Optional[BalanceSummaryBase] = None

    set_results: List[SetResultBase]

    model_config = ConfigDict(from_attributes=True)
