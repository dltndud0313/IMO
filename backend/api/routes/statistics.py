from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.sql import func
from datetime import datetime, timedelta

from core.database import get_db
from core.deps import get_current_user
from models.user import User
from models.session import WorkoutSession, WorkoutMuscleMap, WorkoutBalanceSummary
from schemas.statistics import WeeklySummaryResponse, WeeklyHeatmapResponse, WeeklyBalanceResponse

router = APIRouter()

def get_week_range():
    # 간단히 최근 7일(혹은 현재 주의 Mon-Sun)을 구할 수 있음. 여긴 7일로 가정.
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=7)
    return start_date, end_date

@router.get("/weekly", response_model=WeeklySummaryResponse)
async def get_weekly_summary(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """주간 통계 집계 (총 횟수, 성공률, 보상동작 등)"""
    start_date, end_date = get_week_range()
    
    result = await db.execute(
        select(
            func.sum(WorkoutSession.total_reps).label("total_reps"),
            func.sum(WorkoutSession.duration_sec).label("total_duration_sec"),
            func.sum(WorkoutSession.valid_reps).label("total_valid_reps"),
            func.count(WorkoutSession.id).label("total_sessions"),
            func.sum(WorkoutSession.compensation_count).label("compensation_count")
        ).where(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.started_at >= start_date,
            WorkoutSession.started_at <= end_date
        )
    )
    
    row = result.fetchone()
    
    if not row or row.total_sessions == 0 or row.total_sessions is None:
        # 합의된 빈 깡통 데이터 200 OK 반환
        return WeeklySummaryResponse()
        
    s_total_reps = row.total_reps or 0
    s_valid_reps = row.total_valid_reps or 0
    s_success_rate = (s_valid_reps / s_total_reps * 100.0) if s_total_reps > 0 else 0.0

    return WeeklySummaryResponse(
        total_reps=s_total_reps,
        total_duration_sec=row.total_duration_sec or 0,
        average_success_rate=round(s_success_rate, 2),
        total_sessions=row.total_sessions or 0,
        compensation_count=row.compensation_count or 0
    )


@router.get("/weekly/heatmap", response_model=WeeklyHeatmapResponse)
async def get_weekly_heatmap(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """주간 빈도수 / 근육 사용량 누적 (히트맵)"""
    start_date, end_date = get_week_range()
    
    # 세션들을 먼저 찾음
    sessions_result = await db.execute(
        select(WorkoutSession.session_id).where(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.started_at >= start_date
        )
    )
    session_ids = sessions_result.scalars().all()
    if not session_ids:
         return WeeklyHeatmapResponse() # 빈 딕셔너리 리턴
         
    # 해당 세션들의 근육 맵 누적 연산
    map_result = await db.execute(
        select(
            WorkoutMuscleMap.body_part,
            func.sum(WorkoutMuscleMap.activation_value).label("total_activation")
        ).where(
            WorkoutMuscleMap.session_id.in_(session_ids)
        ).group_by(WorkoutMuscleMap.body_part)
    )
    
    muscle_activation = {}
    for row in map_result.fetchall():
        muscle_activation[row.body_part] = float(row.total_activation)
        
    return WeeklyHeatmapResponse(muscle_activation=muscle_activation)


@router.get("/weekly/balance", response_model=WeeklyBalanceResponse)
async def get_weekly_balance(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """주간 좌우 밸런스 평균"""
    start_date, end_date = get_week_range()
    
    sessions_result = await db.execute(
        select(WorkoutSession.session_id).where(
            WorkoutSession.user_id == current_user.id,
            WorkoutSession.started_at >= start_date
        )
    )
    session_ids = sessions_result.scalars().all()
    if not session_ids:
         return WeeklyBalanceResponse()
         
    balance_result = await db.execute(
        select(
            func.avg(WorkoutBalanceSummary.diff_value).label("avg_diff")
        ).where(
            WorkoutBalanceSummary.session_id.in_(session_ids),
            WorkoutBalanceSummary.enabled == True
        )
    )
    row = balance_result.fetchone()
    
    if not row or row.avg_diff is None:
        return WeeklyBalanceResponse(left_right_balance=0.0, imbalance_reason="no_balance_sensor_data")
        
    return WeeklyBalanceResponse(left_right_balance=float(row.avg_diff), imbalance_reason="derived_from_weekly_avg")
