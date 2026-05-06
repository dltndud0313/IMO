import os
from typing import List
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "IMO Backend API"
    API_V1_STR: str = "/api/v1"

    # 기본값은 로컬 테스트용, docker-compose 등에서는 ENV 변수로 덮어씀
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://imo_user:imo_pass@localhost:5432/imo_db",
    )

    # JWT — access / refresh 시크릿/만료 분리
    # 운영 배포 시 반드시 환경변수로 덮어쓸 것.
    SECRET_KEY: str = os.getenv("JWT_SECRET", "dev_only_access_secret_change_me")
    REFRESH_SECRET_KEY: str = os.getenv(
        "JWT_REFRESH_SECRET", "dev_only_refresh_secret_change_me"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "14"))

    # CORS — 콤마로 구분된 화이트리스트. 미설정 시 와일드카드(개발 편의용)
    CORS_ORIGINS_RAW: str = os.getenv("CORS_ORIGINS", "*")

    # Redis — 통계 read-through 캐시. 컨테이너 외부에서 띄울 땐 ENV 로 덮어쓴다.
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://redis:6379/0")
    # 통계 캐시 기본 TTL (초)
    STATS_CACHE_TTL: int = int(os.getenv("STATS_CACHE_TTL", "300"))
    # 캐시 사용 여부. false 면 cache_get/set/invalidate 모두 no-op (Before/After 비교 측정용).
    CACHE_ENABLED: bool = os.getenv("CACHE_ENABLED", "true").lower() in ("true", "1", "yes")

    # Google Gemini API — 운동 챗봇 (Phase C). 무료 티어 활용.
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    # 모델 토글 — 개발/시연 flash (한도 풍부), 평가 직전 pro (품질).
    LLM_MODEL: str = os.getenv("LLM_MODEL", "gemini-2.5-flash")
    # 대화 히스토리 Redis TTL (초). 1시간 = 3600.
    CHAT_HISTORY_TTL: int = int(os.getenv("CHAT_HISTORY_TTL", "3600"))
    # 한 대화에서 유지할 최대 턴 수 (히스토리 누적 토큰 폭발 방지)
    CHAT_MAX_TURNS: int = int(os.getenv("CHAT_MAX_TURNS", "10"))

    @property
    def CORS_ORIGINS(self) -> List[str]:
        if self.CORS_ORIGINS_RAW.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.CORS_ORIGINS_RAW.split(",") if o.strip()]

    class Config:
        case_sensitive = True


settings = Settings()
