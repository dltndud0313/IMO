from datetime import datetime
from typing import Any, Optional

from pydantic import EmailStr, Field

from schemas._base import CamelModel


# ==== 프로필 (API-04, 05) ====

class UserProfileResponse(CamelModel):
    user_id: int
    email: EmailStr
    nickname: str
    age: Optional[int] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    profile_image_url: Optional[str] = None
    body_scan_data: Optional[Any] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UserProfileUpdate(CamelModel):
    nickname: Optional[str] = Field(default=None, min_length=1, max_length=20)
    age: Optional[int] = Field(default=None, ge=1, le=120)
    gender: Optional[str] = None  # MALE / FEMALE / OTHER
    height_cm: Optional[float] = Field(default=None, ge=50.0, le=300.0)
    weight_kg: Optional[float] = Field(default=None, ge=10.0, le=500.0)
    profile_image_url: Optional[str] = None


# ==== 비밀번호 변경 (신규) ====
class PasswordChangeRequest(CamelModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8)


# ==== 설정 (API-13, 14) — 중첩 구조 ====

class WearableSettings(CamelModel):
    raspberry_pi_ip: Optional[str] = None
    raspberry_pi_port: Optional[int] = None
    glass_connected: bool = False
    glass_device_name: Optional[str] = None


class NotificationSettings(CamelModel):
    exercise_reminder: bool = True
    weekly_report: bool = True


class UserSettingsResponse(CamelModel):
    tts_enabled: bool = True
    wearable: WearableSettings = WearableSettings()
    notifications: NotificationSettings = NotificationSettings()


# ==== 설정 부분 업데이트 ====

class WearableSettingsUpdate(CamelModel):
    raspberry_pi_ip: Optional[str] = None
    raspberry_pi_port: Optional[int] = None
    glass_connected: Optional[bool] = None
    glass_device_name: Optional[str] = None


class NotificationSettingsUpdate(CamelModel):
    exercise_reminder: Optional[bool] = None
    weekly_report: Optional[bool] = None


class UserSettingsUpdate(CamelModel):
    tts_enabled: Optional[bool] = None
    wearable: Optional[WearableSettingsUpdate] = None
    notifications: Optional[NotificationSettingsUpdate] = None


# ==== 데이터 초기화 (API-15) ====

class UserDataDeleteRequest(CamelModel):
    confirm_text: str
