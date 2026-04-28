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

    @property
    def CORS_ORIGINS(self) -> List[str]:
        if self.CORS_ORIGINS_RAW.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.CORS_ORIGINS_RAW.split(",") if o.strip()]

    class Config:
        case_sensitive = True


settings = Settings()
