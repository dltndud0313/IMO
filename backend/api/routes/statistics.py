from datetime import date, datetime, timedelta
from typing import List, Optional, Tuple

from fastapi import APIRouter, Depends, Query
from sqlalchemy import Date, cast, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from core.deps import get_current_user
from core.exceptions import InvalidRequest
from core.responses import success_response
from models.session import (
    WorkoutBalanceSummary,
    WorkoutMuscleMap,
    WorkoutSession,
)
from models.user import User
from schemas.statistics import (
    BalancePair,
    BalanceSide,
    DailyBreakdownItem,
    HeatmapMuscle,
    TrendBlock,
    WeeklyBalanceResponse,
    WeeklyHeatmapResponse,
    WeeklySummary,
    WeeklySummaryResponse,
    WeeklyTrends,
)

router = APIRouter()


# ============================================================
# 매핑 / 헬퍼
# ============================================================

# WorkoutMuscleMap.body_part 의 raw 키 → 명세 §3-4 muscleId/name/side
# Pi 가 보내는 muscle_map 키를 기준으로 작성. 알 수 없는 키는 응답에서 제외하지 않고 그대로 노출.
MUSCLE_LOOKUP = {
    "chest":           {"muscleId": "pectoralis_major", "muscleName": "대흉근",   "side": "CENTER"},
    "left_shoulder":   {"muscleId": "deltoid_left",     "muscleName": "삼각근",   "side": "LEFT"},
    "right_shoulder":  {"muscleId": "deltoid_right",    "muscleName": "삼각근",   "side": "RIGHT"},
    "left_triceps":    {"muscleId": "triceps_left",     "muscleName": "삼두근",   "side": "LEFT"},
    "right_triceps":   {"muscleId": "triceps_right",    "muscleName": "삼두근",   "side": "RIGHT"},
    "left_biceps":     {"muscleId": "biceps_left",      "muscleName": "이두근",   "side": "LEFT"},
    "right_biceps":    {"muscleId": "biceps_right",     "muscleName": "이두근",   "side": "RIGHT"},
    "left_forearm":    {"muscleId": "forearm_left",     "muscleName": "전완근",   "side": "LEFT"},
    "right_forearm":   {"muscleId": "forearm_right",    "muscleName": "전완근",   "side": "RIGHT"},
    "left_lateral":    {"muscleId": "lateral_left",     "muscleName": "측면삼각근", "side": "LEFT"},
    "right_lateral":   {"muscleId": "lateral_right",    "muscleName": "측면삼각근", "side": "RIGHT"},
    "trapezius":       {"muscleId": "trapezius",        "muscleName": "승모근",   "side": "CENTER"},
}


def _activation_level(value: float) -> str:
    """명세 §5-9 ActivationLevel."""
    if value >= 80.0: return "VERY_HIGH"
    if value >= 60.0: return "HIGH"
    if value >= 40.0: return "MEDIUM"
    if value >= 20.0: return "LOW"
    return "VERY_LOW"


def _balance_status(ratio: float) -> str:
    """명세 §5-8 BalanceStatus."""
    if ratio >= 90.0: return "BALANCED"
    if ratio >= 75.0: return "MILD_IMBALANCE"
    return "SIGNIFICANT_IMBALANCE"


def _trend_label(values: List[float]) -> str:
    """첫 vs 마지막 비교로 단순 추세 판정."""
    if len(values) < 2: return "STABLE"
    first, last = values[0], values[-1]
    if abs(last - first) < 1e-3: return "STABLE"
    delta_ratio = (last - first) / max(abs(first), 1e-3)
    if delta_ratio > 0.05: return "INCREASING"
    if delta_ratio < -0.05: return "DECREASING"
    return "STABLE"


def _parse_week_start(week_start: str) -> Tuple[date, date]:
    try:
        d = datetime.strptime(week_start, "%Y-%m-%d").date()
    except ValueError:
        raise InvalidRequest("weekStart must be YYYY-MM-DD")
    end = d + timedelta(days=6)
    return d, end


# ============================================================
# API-10  GET /weekly
# ============================================================
@router.get("/weekly")
async def get_weekly_summary(
    weekStart: str = Query(..., description="주 시작일 YYYY-MM-DD (월요일 권장)"),
    exerciseType: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    week_start_d, week_end_d = _parse_week_start(weekStart)
    start_dt = datetime.combine(week_start_d, datetime.min.time())
    end_dt = datetime.combine(week_end_d, datetime.max.time())

    where_clauses = [
        WorkoutSession.user_id == current_user.id,
        WorkoutSession.started_at >= start_dt,
        WorkoutSession.started_at <= end_dt,
    ]
    if exerciseType:
        where_clauses.append(WorkoutSession.exercise_type == exerciseType)

    rows = (
        await db.execute(
            select(WorkoutSession)
            .where(*where_clauses)
            .order_by(WorkoutSession.started_at.asc())
        )
    ).scalars().all()

    # ---- summary ----
    if rows:
        total_sessions = len(rows)
        total_reps = sum(r.total_reps or 0 for r in rows)
        total_sets = sum(r.set_count or 0 for r in rows)
        total_minutes = sum(int((r.duration_sec or 0) / 60) for r in rows)

        completion_rates = []
        for r in rows:
            target_total = sum(r.target_reps_per_set or [])
            if target_total > 0:
                completion_rates.append(
                    min((r.total_reps or 0) / target_total * 100.0, 100.0)
                )
        avg_completion_rate = (
            sum(completion_rates) / len(completion_rates)
            if completion_rates
            else 0.0
        )

        target_activations = [
            float(r.avg_target_muscle)
            for r in rows
            if r.avg_target_muscle is not None
        ]
        avg_target_activation = (
            sum(target_activations) / len(target_activations)
            if target_activations
            else 0.0
        )

        summary = WeeklySummary(
            total_sessions=total_sessions,
            total_reps=total_reps,
            total_sets=total_sets,
            avg_completion_rate=round(avg_completion_rate, 1),
            avg_target_activation=round(avg_target_activation, 1),
            total_exercise_minutes=total_minutes,
        )
    else:
        summary = WeeklySummary()

    # ---- dailyBreakdown (7일 모두 포함, 운동 없는 날은 0) ----
    daily_map: dict[str, DailyBreakdownItem] = {}
    for offset in range(7):
        d = (week_start_d + timedelta(days=offset)).isoformat()
        daily_map[d] = DailyBreakdownItem(date=d, sessions=0, total_reps=0)
    for r in rows:
        if not r.started_at:
            continue
        d = r.started_at.date().isoformat()
        if d in daily_map:
            daily_map[d].sessions += 1
            daily_map[d].total_reps += r.total_reps or 0
    daily_breakdown = list(daily_map.values())

    # ---- trends (운동 수행한 세션만 시계열) ----
    target_act_values, target_act_dates = [], []
    comp_rate_values, comp_rate_dates = [], []
    fatigue_values, fatigue_dates = [], []

    for r in rows:
        if not r.started_at:
            continue
        d = r.started_at.date().isoformat()

        if r.avg_target_muscle is not None:
            target_act_values.append(round(float(r.avg_target_muscle), 1))
            target_act_dates.append(d)

        if r.total_reps and r.total_reps > 0:
            comp_rate = (r.compensation_count or 0) / r.total_reps * 100.0
            comp_rate_values.append(round(comp_rate, 1))
            comp_rate_dates.append(d)

        # fatigue 점수 — onset 이 빨리 올수록(낮은 set/rep) 피로 큼.
        # 간이지표: fatigue_onset_set 이 nullable 이므로 있을 때만 시계열에 포함.
        if r.fatigue_onset_set is not None:
            # set_count 대비 onset 의 늦음 비율 → 낮을수록 피로 빠름.
            # trend 의미를 위해 "피로 빠름 = 큰 값"으로 변환.
            sc = max(r.set_count or 1, 1)
            fatigue_score = max(0.0, (sc - r.fatigue_onset_set) / sc * 100.0)
            fatigue_values.append(round(fatigue_score, 1))
            fatigue_dates.append(d)

    trends = WeeklyTrends(
        target_activation=TrendBlock(
            values=target_act_values,
            dates=target_act_dates,
            trend=_trend_label(target_act_values),
        ),
        compensation_rate=TrendBlock(
            values=comp_rate_values,
            dates=comp_rate_dates,
            trend=_trend_label(comp_rate_values),
        ),
        fatigue=TrendBlock(
            values=fatigue_values,
            dates=fatigue_dates,
            trend=_trend_label(fatigue_values),
        ),
    )

    payload = WeeklySummaryResponse(
        week_start=week_start_d.isoformat(),
        week_end=week_end_d.isoformat(),
        exercise_type=exerciseType,
        summary=summary,
        daily_breakdown=daily_breakdown,
        trends=trends,
    )
    return success_response(payload.model_dump(by_alias=True, mode="json"))


# ============================================================
# API-11  GET /weekly/heatmap
# ============================================================
@router.get("/weekly/heatmap")
async def get_weekly_heatmap(
    weekStart: str = Query(...),
    exerciseType: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    week_start_d, week_end_d = _parse_week_start(weekStart)
    start_dt = datetime.combine(week_start_d, datetime.min.time())
    end_dt = datetime.combine(week_end_d, datetime.max.time())

    # 해당 주차 사용자 세션 ID
    sess_clauses = [
        WorkoutSession.user_id == current_user.id,
        WorkoutSession.started_at >= start_dt,
        WorkoutSession.started_at <= end_dt,
    ]
    if exerciseType:
        sess_clauses.append(WorkoutSession.exercise_type == exerciseType)

    session_ids = (
        await db.execute(select(WorkoutSession.session_id).where(*sess_clauses))
    ).scalars().all()

    if not session_ids:
        empty = WeeklyHeatmapResponse(
            week_start=week_start_d.isoformat(),
            week_end=week_end_d.isoformat(),
            muscles=[],
        )
        return success_response(empty.model_dump(by_alias=True, mode="json"))

    # 근육 평균 + 출현 세션 카운트
    rows = (
        await db.execute(
            select(
                WorkoutMuscleMap.body_part,
                func.avg(WorkoutMuscleMap.activation_value).label("avg_act"),
                func.count(func.distinct(WorkoutMuscleMap.session_id)).label("sess_cnt"),
            )
            .where(WorkoutMuscleMap.session_id.in_(session_ids))
            .group_by(WorkoutMuscleMap.body_part)
        )
    ).all()

    muscles: List[HeatmapMuscle] = []
    for body_part, avg_act, sess_cnt in rows:
        avg = float(avg_act or 0.0)
        meta = MUSCLE_LOOKUP.get(
            body_part,
            {"muscleId": body_part, "muscleName": body_part, "side": "CENTER"},
        )
        muscles.append(
            HeatmapMuscle(
                muscle_id=meta["muscleId"],
                muscle_name=meta["muscleName"],
                side=meta["side"],
                avg_activation=round(avg, 1),
                activation_level=_activation_level(avg),
                session_count=int(sess_cnt or 0),
            )
        )

    payload = WeeklyHeatmapResponse(
        week_start=week_start_d.isoformat(),
        week_end=week_end_d.isoformat(),
        muscles=muscles,
    )
    return success_response(payload.model_dump(by_alias=True, mode="json"))


# ============================================================
# API-12  GET /weekly/balance
# ============================================================
@router.get("/weekly/balance")
async def get_weekly_balance(
    weekStart: str = Query(...),
    exerciseType: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    week_start_d, week_end_d = _parse_week_start(weekStart)
    start_dt = datetime.combine(week_start_d, datetime.min.time())
    end_dt = datetime.combine(week_end_d, datetime.max.time())

    sess_clauses = [
        WorkoutSession.user_id == current_user.id,
        WorkoutSession.started_at >= start_dt,
        WorkoutSession.started_at <= end_dt,
    ]
    if exerciseType:
        sess_clauses.append(WorkoutSession.exercise_type == exerciseType)

    session_ids = (
        await db.execute(select(WorkoutSession.session_id).where(*sess_clauses))
    ).scalars().all()

    if not session_ids:
        empty = WeeklyBalanceResponse(
            week_start=week_start_d.isoformat(),
            week_end=week_end_d.isoformat(),
            balance_pairs=[],
        )
        return success_response(empty.model_dump(by_alias=True, mode="json"))

    # 근육별 평균/최대/최소 활성도 (좌/우 분리)
    rows = (
        await db.execute(
            select(
                WorkoutMuscleMap.body_part,
                func.avg(WorkoutMuscleMap.activation_value).label("avg_v"),
                func.max(WorkoutMuscleMap.activation_value).label("max_v"),
                func.min(WorkoutMuscleMap.activation_value).label("min_v"),
            )
            .where(WorkoutMuscleMap.session_id.in_(session_ids))
            .group_by(WorkoutMuscleMap.body_part)
        )
    ).all()

    # body_part 별 통계 → 근육명+side 로 재그룹
    by_muscle: dict[str, dict[str, BalanceSide]] = {}
    for body_part, avg_v, max_v, min_v in rows:
        meta = MUSCLE_LOOKUP.get(body_part)
        if not meta or meta["side"] not in ("LEFT", "RIGHT"):
            continue
        side_block = BalanceSide(
            avg_activation=round(float(avg_v or 0.0), 1),
            max_activation=round(float(max_v or 0.0), 1),
            min_activation=round(float(min_v or 0.0), 1),
        )
        bucket = by_muscle.setdefault(meta["muscleName"], {})
        bucket[meta["side"]] = side_block

    pairs: List[BalancePair] = []
    for muscle_name, sides in by_muscle.items():
        left = sides.get("LEFT")
        right = sides.get("RIGHT")
        if not left or not right:
            continue  # 좌우 한쪽만 있으면 제외

        max_avg = max(left.avg_activation, right.avg_activation)
        if max_avg <= 0:
            ratio = 0.0
        else:
            ratio = min(left.avg_activation, right.avg_activation) / max_avg * 100.0

        pairs.append(
            BalancePair(
                muscle_name=muscle_name,
                left=left,
                right=right,
                balance_ratio=round(ratio, 1),
                dominant_side="LEFT"
                if left.avg_activation > right.avg_activation
                else "RIGHT",
                status=_balance_status(ratio),
            )
        )

    payload = WeeklyBalanceResponse(
        week_start=week_start_d.isoformat(),
        week_end=week_end_d.isoformat(),
        balance_pairs=pairs,
    )
    return success_response(payload.model_dump(by_alias=True, mode="json"))
