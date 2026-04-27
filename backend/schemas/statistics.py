from pydantic import BaseModel
from typing import Dict, List

class WeeklySummaryResponse(BaseModel):
    total_reps: int = 0
    total_duration_sec: int = 0
    average_success_rate: float = 0.0
    total_sessions: int = 0
    compensation_count: int = 0

class WeeklyHeatmapResponse(BaseModel):
    muscle_activation: Dict[str, float] = {}

class WeeklyBalanceResponse(BaseModel):
    left_right_balance: float = 0.0
    imbalance_reason: str = "no_data_or_perfect"
