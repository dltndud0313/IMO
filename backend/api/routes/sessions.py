from calendar import monthrange
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import Date, cast, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from core.deps import get_current_user
from core.exceptions import InvalidRequest, SessionNotFound
from core.responses import success_response
from models.session import (
    WorkoutBalanceSummary,
    WorkoutCalibration,
    WorkoutMuscleMap,
    WorkoutSession,
    WorkoutSetResult,
)
from models.user import User
from schemas.session import SessionCreate

router = APIRouter()


# ---- 좌우 밸런스 라벨링 (명세 §5-8) ----
def _balance_status(ratio: float) -> str:
    if ratio >= 90.0:
        return "BALANCED"
    if ratio >= 75.0:
        return "MILD_IMBALANCE"
    return "SIGNIFICANT_IMBALANCE"


# ============================================================
# API-06  POST /sessions
# ============================================================
@router.post("", status_code=status.HTTP_201_CREATED)
@router.post("/", status_code=status.HTTP_201_CREATED, include_in_schema=False)
async def create_session(
    payload: SessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """앱이 보낸 session_result 1건을 5개 테이블에 분산 저장.

    user_id 는 payload 가 아니라 JWT 의 current_user.id 를 강제 사용.
    """
    db_session = WorkoutSession(
        user_id=current_user.id,
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
        comment=payload.comment,
    )
    db.add(db_session)
    # 자식 테이블들이 session_id(unique String) 를 FK 로 참조하므로
    # SQLAlchemy 의 PK 기반 의존성 정렬이 동작하지 않는다.
    # 부모를 먼저 flush 해서 DB 에 INSERT 한 뒤 자식들을 추가한다.
    await db.flush()

    for set_res in payload.set_results:
        db.add(
            WorkoutSetResult(
                session_id=payload.session_id,
                set_index=set_res.set_index,
                target_reps=set_res.target_reps,
                actual_reps=set_res.actual_reps,
                compensation_count=set_res.compensation_count,
                avg_speed=set_res.avg_speed,
                started_at=set_res.started_at,
                ended_at=set_res.ended_at,
            )
        )

    if payload.calibration_summary:
        db.add(
            WorkoutCalibration(
                session_id=payload.session_id,
                ch1_mvc=payload.calibration_summary.ch1_mvc,
                ch2_mvc=payload.calibration_summary.ch2_mvc,
                ch3_mvc=payload.calibration_summary.ch3_mvc,
            )
        )

    if payload.muscle_map:
        for body_part, value in payload.muscle_map.items():
            db.add(
                WorkoutMuscleMap(
                    session_id=payload.session_id,
                    body_part=body_part,
                    activation_value=value,
                )
            )

    if payload.balance_summary:
        db.add(
            WorkoutBalanceSummary(
                session_id=payload.session_id,
                enabled=payload.balance_summary.enabled,
                reason=payload.balance_summary.reason,
                left_value=payload.balance_summary.left_value,
                right_value=payload.balance_summary.right_value,
                diff_value=payload.balance_summary.diff_value,
                balance_label=payload.balance_summary.balance_label,
            )
        )

    await db.commit()
    await db.refresh(db_session)

    return success_response(
        {
            "sessionId": payload.session_id,
            "createdAt": (db_session.created_at or datetime.utcnow()).isoformat(),
        }
    )


# ============================================================
# API-07  GET /sessions
# ============================================================
@router.get("")
@router.get("/", include_in_schema=False)
async def list_sessions(
    date: Optional[str] = Query(None, description="YYYY-MM-DD 단일 날짜"),
    month: Optional[str] = Query(None, description="YYYY-MM 월 단위"),
    exerciseType: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    where_clauses = [WorkoutSession.user_id == current_user.id]

    if date:
        try:
            d = datetime.strptime(date, "%Y-%m-%d").date()
        except ValueError:
            raise InvalidRequest("date must be YYYY-MM-DD")
        where_clauses.append(cast(WorkoutSession.started_at, Date) == d)

    if month:
        try:
            year_str, mon_str = month.split("-")
            year, mon = int(year_str), int(mon_str)
            if not (1 <= mon <= 12):
                raise ValueError
        except (ValueError, AttributeError):
            raise InvalidRequest("month must be YYYY-MM")
        first = datetime(year, mon, 1)
        _, last_day = monthrange(year, mon)
        last = datetime(year, mon, last_day, 23, 59, 59)
        where_clauses.append(WorkoutSession.started_at >= first)
        where_clauses.append(WorkoutSession.started_at <= last)

    if exerciseType:
        where_clauses.append(WorkoutSession.exercise_type == exerciseType)

    total_count = (
        await db.execute(
            select(func.count()).select_from(WorkoutSession).where(*where_clauses)
        )
    ).scalar() or 0

    rows = (
        await db.execute(
            select(WorkoutSession)
            .where(*where_clauses)
            .order_by(WorkoutSession.started_at.desc())
            .offset((page - 1) * size)
            .limit(size)
        )
    ).scalars().all()

    date_rows = (
        await db.execute(
            select(cast(WorkoutSession.started_at, Date))
            .where(*where_clauses)
            .distinct()
            .order_by(cast(WorkoutSession.started_at, Date).asc())
        )
    ).scalars().all()
    exercise_dates = [d.isoformat() for d in date_rows if d is not None]

    sessions = []
    for s in rows:
        target_total = sum(s.target_reps_per_set or [])
        completion = (
            (s.total_reps / target_total * 100.0) if target_total > 0 else 0.0
        )
        sessions.append(
            {
                "sessionId": s.session_id,
                "exerciseType": s.exercise_type,
                "date": s.started_at.date().isoformat() if s.started_at else None,
                "startTime": s.started_at.isoformat() if s.started_at else None,
                "endTime": s.ended_at.isoformat() if s.ended_at else None,
                "totalReps": s.total_reps,
                "totalSets": s.set_count,
                "completionRate": round(min(completion, 100.0), 1),
                "avgTargetActivation": float(s.avg_target_muscle)
                if s.avg_target_muscle is not None
                else 0.0,
            }
        )

    total_pages = (total_count + size - 1) // size if total_count > 0 else 0

    return success_response(
        {
            "sessions": sessions,
            "exerciseDates": exercise_dates,
            "pagination": {
                "page": page,
                "size": size,
                "totalCount": total_count,
                "totalPages": total_pages,
            },
        }
    )


# ============================================================
# API-08  GET /sessions/{sessionId}  — 풍부화 응답
# ============================================================
@router.get("/{session_id}")
async def get_session_detail(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = (
        await db.execute(
            select(WorkoutSession).where(
                WorkoutSession.session_id == session_id,
                WorkoutSession.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if not session:
        raise SessionNotFound()

    set_rows = (
        await db.execute(
            select(WorkoutSetResult)
            .where(WorkoutSetResult.session_id == session_id)
            .order_by(WorkoutSetResult.set_index.asc())
        )
    ).scalars().all()

    balance = (
        await db.execute(
            select(WorkoutBalanceSummary).where(
                WorkoutBalanceSummary.session_id == session_id
            )
        )
    ).scalar_one_or_none()

    # ---- sets[] ----
    sets_payload = []
    for s in set_rows:
        duration_sec = 0
        if s.started_at and s.ended_at:
            duration_sec = int((s.ended_at - s.started_at).total_seconds())
        sets_payload.append(
            {
                "setNumber": s.set_index,
                "targetReps": s.target_reps,
                "actualReps": s.actual_reps,
                "durationSeconds": duration_sec,
                "restDurationSeconds": session.rest_sec,
                "avgSpeed": s.avg_speed,
                "compensationCount": s.compensation_count,
                # 아래 두 필드는 set 단위 저장 미구현 → 평균값/0 으로 폴백
                "avgTargetActivation": float(session.avg_target_muscle)
                if session.avg_target_muscle is not None
                else 0.0,
                "stabilityScore": 0.0,
                # rep 단위 데이터 미수신 (Option A) → 빈 배열
                "repDetails": [],
            }
        )

    # ---- overallSummary ----
    target_total = sum(session.target_reps_per_set or [])
    completion = (
        (session.total_reps / target_total * 100.0) if target_total > 0 else 0.0
    )
    overall_summary = {
        "totalReps": session.total_reps,
        "totalTargetReps": target_total,
        "completionRate": round(min(completion, 100.0), 1),
        "avgTargetActivation": float(session.avg_target_muscle)
        if session.avg_target_muscle is not None
        else 0.0,
        "totalCompensationCount": session.compensation_count,
        "avgStabilityScore": 0.0,
        "fatigueOnsetSet": session.fatigue_onset_set,
        "fatigueOnsetRep": session.fatigue_onset_rep,
    }

    # ---- muscleBalance ----
    if balance and balance.enabled and balance.left_value and balance.right_value:
        left = float(balance.left_value)
        right = float(balance.right_value)
        ratio = (
            (min(left, right) / max(left, right) * 100.0)
            if max(left, right) > 0
            else 0.0
        )
        muscle_balance = {
            "leftAvg": round(left, 1),
            "rightAvg": round(right, 1),
            "balanceRatio": round(ratio, 1),
            "status": _balance_status(ratio),
        }
    else:
        muscle_balance = {
            "leftAvg": 0.0,
            "rightAvg": 0.0,
            "balanceRatio": 0.0,
            "status": "BALANCED",
        }

    # ---- graphs (Option A — rep 단위 timeline 빈 배열) ----
    graphs = {
        "repActivationTimeline": [],
        "speedTimeline": [],
        "stabilityTimeline": [],
    }

    # ---- 전체 응답 ----
    total_duration_sec = session.duration_sec or (
        int((session.ended_at - session.started_at).total_seconds())
        if session.started_at and session.ended_at
        else 0
    )

    payload = {
        "sessionId": session.session_id,
        "exerciseType": session.exercise_type,
        "startTime": session.started_at.isoformat() if session.started_at else None,
        "endTime": session.ended_at.isoformat() if session.ended_at else None,
        "totalDurationSeconds": total_duration_sec,
        "sets": sets_payload,
        "overallSummary": overall_summary,
        "muscleBalance": muscle_balance,
        "graphs": graphs,
    }
    return success_response(payload)


# ============================================================
# API-09  DELETE /sessions/{sessionId}
# ============================================================
@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = (
        await db.execute(
            select(WorkoutSession).where(
                WorkoutSession.session_id == session_id,
                WorkoutSession.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if not session:
        raise SessionNotFound()

    await db.delete(session)  # FK CASCADE 로 자식 테이블 동시 삭제
    await db.commit()

    return success_response({"deletedSessionId": session_id})
