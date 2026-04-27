from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker

from core.config import settings

# SQLAlchemy 비동기 엔진 설정
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=True, # 쿼리 로깅 활성화 (운영환경에선 False 권장)
)

# 비동기 세션 팩토리 생성
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# ORM 모델들이 상속받을 베이스 클래스
Base = declarative_base()

# 의존성 주입용 세션 제너레이터
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
