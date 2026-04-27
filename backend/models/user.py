from sqlalchemy import Column, BigInteger, String, DateTime, Boolean, DECIMAL, ForeignKey, Integer
from sqlalchemy.sql import func
from core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    nickname = Column(String(50), nullable=False)
    
    # 프로필 부가 정보 (가입/수정 시 입력)
    age = Column(Integer, nullable=True)
    gender = Column(String(10), nullable=True)
    height_cm = Column(DECIMAL(5,1), nullable=True)
    weight_kg = Column(DECIMAL(5,1), nullable=True)
    profile_image_url = Column(String(255), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class UserSettings(Base):
    __tablename__ = "user_settings"
    
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    
    tts_enabled = Column(Boolean, default=True, nullable=False)
    raspberry_pi_ip = Column(String(50), nullable=True)
    wearable_type = Column(String(50), default="none", nullable=False)
    auto_connect = Column(Boolean, default=False, nullable=False)
    
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
