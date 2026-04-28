from datetime import date as date_t
from typing import List, Optional

from schemas._base import CamelModel


# ==== /weekly  (API-10) ====

class WeeklySummary(CamelModel):
    total_sessions: int = 0
    total_reps: int = 0
    total_sets: int = 0
    avg_completion_rate: float = 0.0
    avg_target_activation: float = 0.0
    total_exercise_minutes: int = 0


class DailyBreakdownItem(CamelModel):
    date: str
    sessions: int = 0
    total_reps: int = 0


class TrendBlock(CamelModel):
    values: List[float] = []
    dates: List[str] = []
    trend: str = "STABLE"  # INCREASING / DECREASING / STABLE


class WeeklyTrends(CamelModel):
    target_activation: TrendBlock = TrendBlock()
    compensation_rate: TrendBlock = TrendBlock()
    fatigue: TrendBlock = TrendBlock()


class WeeklySummaryResponse(CamelModel):
    week_start: str
    week_end: str
    exercise_type: Optional[str] = None
    summary: WeeklySummary = WeeklySummary()
    daily_breakdown: List[DailyBreakdownItem] = []
    trends: WeeklyTrends = WeeklyTrends()


# ==== /weekly/heatmap  (API-11) ====

class HeatmapMuscle(CamelModel):
    muscle_id: str
    muscle_name: str
    side: str  # LEFT / RIGHT / CENTER
    avg_activation: float = 0.0
    activation_level: str  # VERY_LOW / LOW / MEDIUM / HIGH / VERY_HIGH
    session_count: int = 0


class WeeklyHeatmapResponse(CamelModel):
    week_start: str
    week_end: str
    muscles: List[HeatmapMuscle] = []


# ==== /weekly/balance  (API-12) ====

class BalanceSide(CamelModel):
    avg_activation: float = 0.0
    max_activation: float = 0.0
    min_activation: float = 0.0


class BalancePair(CamelModel):
    muscle_name: str
    left: BalanceSide
    right: BalanceSide
    balance_ratio: float = 0.0
    dominant_side: str = "LEFT"  # LEFT / RIGHT
    status: str = "BALANCED"  # BALANCED / MILD_IMBALANCE / SIGNIFICANT_IMBALANCE


class WeeklyBalanceResponse(CamelModel):
    week_start: str
    week_end: str
    balance_pairs: List[BalancePair] = []
