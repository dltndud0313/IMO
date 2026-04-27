from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from models.session import (
    WorkoutSession, WorkoutSetResult, WorkoutCalibration, 
    WorkoutMuscleMap, WorkoutBalanceSummary
)
from core.deps import get_current_user
from models.user import User
from schemas.session import SessionCreate

router = APIRouter()

@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_session(
    payload: SessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    앱으로부터 운동 세션 1건을 통째로 받아서 5개 테이블에 나누어 Insert (트랜잭션)
    """
    # 1. WorkoutSessions (부모 레코드) 생성
    db_session = WorkoutSession(
        user_id=payload.user_id,
        session_id=payload.session_id,
        exercise_type=payload.exercise_type,
        status=payload.status,
        end_reason=payload.end_reason,
        started_at=payload.started_at,
        ended_at=payload.ended_at,
        duration_sec=payload.duration_sec,
        set_count=payload.set_count,
        target_reps_per_set=payload.target_reps_per_set,
        actual_reps_per_set=payload.actual_reps_per_set,
        rest_sec=payload.rest_sec,
        total_reps=payload.total_reps,
        valid_reps=payload.valid_reps,
        avg_target_muscle=payload.avg_target_muscle,
        avg_assist_muscle=payload.avg_assist_muscle,
        avg_compensator=payload.avg_compensator,
        compensation_count=payload.compensation_count,
        fatigue_onset_set=payload.fatigue_onset_set,
        fatigue_onset_rep=payload.fatigue_onset_rep,
        comment=payload.comment
    )
    db.add(db_session)
    
    # 2. WorkoutSetResults
    for s_idx, set_res in enumerate(payload.set_results):
        db_set = WorkoutSetResult(
            session_id=payload.session_id,
            set_index=set_res.set_index,
            target_reps=set_res.target_reps,
            actual_reps=set_res.actual_reps,
            compensation_count=set_res.compensation_count,
            avg_speed=set_res.avg_speed,
            started_at=set_res.started_at,
            ended_at=set_res.ended_at
        )
        db.add(db_set)
        
    # 3. WorkoutCalibration
    if payload.calibration_summary:
        db_calib = WorkoutCalibration(
            session_id=payload.session_id,
            ch1_mvc=payload.calibration_summary.ch1_mvc,
            ch2_mvc=payload.calibration_summary.ch2_mvc,
            ch3_mvc=payload.calibration_summary.ch3_mvc
        )
        db.add(db_calib)
        
    # 4. WorkoutMuscleMap
    if payload.muscle_map:
        for body_part, act_value in payload.muscle_map.items():
            db_muscle = WorkoutMuscleMap(
                session_id=payload.session_id,
                body_part=body_part,
                activation_value=act_value
            )
            db.add(db_muscle)
            
    # 5. WorkoutBalanceSummary
    if payload.balance_summary:
        db_bal = WorkoutBalanceSummary(
            session_id=payload.session_id,
            enabled=payload.balance_summary.enabled,
            reason=payload.balance_summary.reason,
            left_value=payload.balance_summary.left_value,
            right_value=payload.balance_summary.right_value,
            diff_value=payload.balance_summary.diff_value,
            balance_label=payload.balance_summary.balance_label
        )
        db.add(db_bal)

    # 커밋 (에러 시 라우터에서 자동 롤백됨)
    await db.commit()
    
    return {
        "success": True, 
        "data": {
            "sessionId": payload.session_id,
            "message": "Session tightly stored into PostgreSQL tables"
        }
    }

@router.get("/")
async def list_sessions(
    limit: int = 10,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """내 전체 세션 목록 조회"""
    result = await db.execute(
        select(WorkoutSession)
        .where(WorkoutSession.user_id == current_user.id)
        .order_by(WorkoutSession.started_at.desc())
        .offset(offset).limit(limit)
    )
    sessions = result.scalars().all()
    
    return {"success": True, "data": sessions}

@router.get("/{session_id}")
async def get_session_detail(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """단일 세션 상세 정보 조회 (세트 정보 포함)"""
    result = await db.execute(select(WorkoutSession).where(
        WorkoutSession.session_id == session_id,
        WorkoutSession.user_id == current_user.id
    ))
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    set_results = await db.execute(select(WorkoutSetResult).where(WorkoutSetResult.session_id == session_id))
    
    return {
        "success": True,
        "data": {
            "session": session,
            "sets": set_results.scalars().all()
        }
    }

@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """단일 운동 세션 및 관련 데이터 영구 삭제"""
    result = await db.execute(select(WorkoutSession).where(
        WorkoutSession.session_id == session_id,
        WorkoutSession.user_id == current_user.id
    ))
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    await db.delete(session) # ondelete="CASCADE" 로 인해 딸려있는 결과/근육맵 다 자동 삭제 됨
    await db.commit()
    
    return {"success": True, "message": "Session and all related data deleted successfully"}
