from pydantic import BaseModel, ConfigDict
from typing import List, Optional, Dict
from datetime import datetime

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
    """
    앱에서 POST /sessions 로 보내는 페이로드 완벽 매핑
    """
    user_id: int
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
    muscle_map: Optional[Dict[str, float]] = None # {"chest": 68.0, ...}
    balance_summary: Optional[BalanceSummaryBase] = None
    
    set_results: List[SetResultBase]
    
    model_config = ConfigDict(from_attributes=True)
