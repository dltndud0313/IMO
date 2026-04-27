from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

# ==== 프로필 ====
class UserProfileBase(BaseModel):
    nickname: str
    age: Optional[int] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    profile_image_url: Optional[str] = None

class UserProfileResponse(UserProfileBase):
    id: int
    email: str
    
    model_config = ConfigDict(from_attributes=True)

class UserProfileUpdate(BaseModel):
    nickname: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    profile_image_url: Optional[str] = None

# ==== 앱 설정 ====
class UserSettingsBase(BaseModel):
    tts_enabled: bool
    raspberry_pi_ip: Optional[str] = None
    wearable_type: str
    auto_connect: bool

class UserSettingsResponse(UserSettingsBase):
    model_config = ConfigDict(from_attributes=True)
