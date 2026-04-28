from datetime import datetime

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from core.deps import get_current_user
from core.exceptions import UserNotFound, ValidationError
from core.responses import success_response
from models.session import WorkoutSession
from models.user import User, UserSettings
from schemas.user import (
    NotificationSettings,
    UserDataDeleteRequest,
    UserProfileResponse,
    UserProfileUpdate,
    UserSettingsResponse,
    UserSettingsUpdate,
    WearableSettings,
)

router = APIRouter()


CONFIRM_TEXT = "DELETE ALL DATA"


def _to_profile_response(user: User) -> UserProfileResponse:
    return UserProfileResponse(
        user_id=user.id,
        email=user.email,
        nickname=user.nickname,
        age=user.age,
        gender=user.gender,
        height_cm=float(user.height_cm) if user.height_cm is not None else None,
        weight_kg=float(user.weight_kg) if user.weight_kg is not None else None,
        profile_image_url=user.profile_image_url,
        body_scan_data=user.body_scan_data,
        created_at=user.created_at,
        updated_at=user.updated_at,
    )


def _to_settings_response(s: UserSettings) -> UserSettingsResponse:
    return UserSettingsResponse(
        tts_enabled=s.tts_enabled,
        wearable=WearableSettings(
            raspberry_pi_ip=s.raspberry_pi_ip,
            raspberry_pi_port=s.raspberry_pi_port,
            glass_connected=s.glass_connected,
            glass_device_name=s.glass_device_name,
        ),
        notifications=NotificationSettings(
            exercise_reminder=s.notifications_exercise_reminder,
            weekly_report=s.notifications_weekly_report,
        ),
    )


# ==== Profile (API-04, 05) ====

@router.get("/me/profile")
async def read_user_profile(current_user: User = Depends(get_current_user)):
    payload = _to_profile_response(current_user)
    return success_response(payload.model_dump(by_alias=True, mode="json"))


@router.put("/me/profile")
async def update_user_profile(
    profile_in: UserProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = profile_in.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(current_user, key, value)

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    payload = _to_profile_response(current_user)
    return success_response(payload.model_dump(by_alias=True, mode="json"))


# ==== Settings (API-13, 14) ====

async def _get_or_create_settings(
    db: AsyncSession, user_id: int
) -> UserSettings:
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == user_id)
    )
    s = result.scalar_one_or_none()
    if s is None:
        s = UserSettings(user_id=user_id)
        db.add(s)
        await db.commit()
        await db.refresh(s)
    return s


@router.get("/me/settings")
async def read_user_settings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    s = await _get_or_create_settings(db, current_user.id)
    payload = _to_settings_response(s)
    return success_response(payload.model_dump(by_alias=True, mode="json"))


@router.put("/me/settings")
async def update_user_settings(
    settings_in: UserSettingsUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    s = await _get_or_create_settings(db, current_user.id)

    # 부분 업데이트 — 보낸 필드만 반영
    incoming = settings_in.model_dump(exclude_unset=True)

    if "tts_enabled" in incoming:
        s.tts_enabled = incoming["tts_enabled"]

    wearable = incoming.get("wearable")
    if wearable:
        if "raspberry_pi_ip" in wearable:
            s.raspberry_pi_ip = wearable["raspberry_pi_ip"]
        if "raspberry_pi_port" in wearable:
            s.raspberry_pi_port = wearable["raspberry_pi_port"]
        if "glass_connected" in wearable:
            s.glass_connected = wearable["glass_connected"]
        if "glass_device_name" in wearable:
            s.glass_device_name = wearable["glass_device_name"]

    notifications = incoming.get("notifications")
    if notifications:
        if "exercise_reminder" in notifications:
            s.notifications_exercise_reminder = notifications["exercise_reminder"]
        if "weekly_report" in notifications:
            s.notifications_weekly_report = notifications["weekly_report"]

    db.add(s)
    await db.commit()
    await db.refresh(s)

    payload = _to_settings_response(s)
    return success_response(payload.model_dump(by_alias=True, mode="json"))


# ==== 데이터 초기화 (API-15) ====

@router.delete("/me/data", status_code=status.HTTP_200_OK)
async def reset_user_data(
    body: UserDataDeleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.confirm_text != CONFIRM_TEXT:
        raise ValidationError(
            f"confirmText must be exactly '{CONFIRM_TEXT}'"
        )

    # 삭제 전 카운트
    count_q = select(WorkoutSession.id).where(
        WorkoutSession.user_id == current_user.id
    )
    deleted_count = len((await db.execute(count_q)).scalars().all())

    # WorkoutSession 삭제 (FK CASCADE 로 자식 테이블 동시 삭제)
    await db.execute(
        WorkoutSession.__table__.delete().where(
            WorkoutSession.user_id == current_user.id
        )
    )
    await db.commit()

    return success_response(
        {
            "deletedSessionCount": deleted_count,
            "deletedAt": datetime.utcnow().isoformat() + "Z",
        }
    )
