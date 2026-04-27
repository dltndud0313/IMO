from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from core.deps import get_current_user
from models.user import User, UserSettings
from schemas.user import UserProfileResponse, UserProfileUpdate, UserSettingsResponse, UserSettingsBase

router = APIRouter()

@router.get("/me/profile", response_model=UserProfileResponse)
async def read_user_profile(
    current_user: User = Depends(get_current_user)
):
    """현재 로그인한 사용자의 프로필 조회"""
    return current_user

@router.put("/me/profile", response_model=UserProfileResponse)
async def update_user_profile(
    profile_in: UserProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """프로필 수정"""
    if profile_in.nickname is not None: current_user.nickname = profile_in.nickname
    if profile_in.age is not None: current_user.age = profile_in.age
    if profile_in.gender is not None: current_user.gender = profile_in.gender
    if profile_in.height_cm is not None: current_user.height_cm = profile_in.height_cm
    if profile_in.weight_kg is not None: current_user.weight_kg = profile_in.weight_kg
    if profile_in.profile_image_url is not None: current_user.profile_image_url = profile_in.profile_image_url
    
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    
    return current_user

@router.get("/me/settings", response_model=UserSettingsResponse)
async def read_user_settings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(UserSettings).where(UserSettings.user_id == current_user.id))
    settings = result.scalar_one_or_none()
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    return settings

@router.put("/me/settings", response_model=UserSettingsResponse)
async def update_user_settings(
    settings_in: UserSettingsBase,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(UserSettings).where(UserSettings.user_id == current_user.id))
    settings = result.scalar_one_or_none()
    if not settings:
         raise HTTPException(status_code=404, detail="Settings not found")
         
    settings.tts_enabled = settings_in.tts_enabled
    settings.raspberry_pi_ip = settings_in.raspberry_pi_ip
    settings.wearable_type = settings_in.wearable_type
    settings.auto_connect = settings_in.auto_connect
    
    db.add(settings)
    await db.commit()
    await db.refresh(settings)
    return settings
