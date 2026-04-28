from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DECIMAL,
    DateTime,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import JSONB
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
    height_cm = Column(DECIMAL(5, 1), nullable=True)
    weight_kg = Column(DECIMAL(5, 1), nullable=True)
    profile_image_url = Column(String(255), nullable=True)
    # 명세 API-04 — 바디 스캔 결과 페이로드 (인프라 미구현, nullable)
    body_scan_data = Column(JSONB, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class UserSettings(Base):
    """명세 API-13/14 의 중첩 구조를 평면 컬럼으로 저장.

    응답 시 schemas/user.py 에서 wearable / notifications 로 그룹핑한다.
    """

    __tablename__ = "user_settings"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # TTS
    tts_enabled = Column(Boolean, default=True, nullable=False)

    # wearable.* (명세 API-13)
    raspberry_pi_ip = Column(String(50), nullable=True)
    raspberry_pi_port = Column(Integer, nullable=True)
    glass_connected = Column(Boolean, default=False, nullable=False)
    glass_device_name = Column(String(100), nullable=True)

    # notifications.* (명세 API-13) — 푸시 발송 인프라는 미구현, 플래그만 보관
    notifications_exercise_reminder = Column(Boolean, default=True, nullable=False)
    notifications_weekly_report = Column(Boolean, default=True, nullable=False)

    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
