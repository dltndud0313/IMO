import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "IMO Backend API"
    API_V1_STR: str = "/api/v1"
    
    # 기본값은 로컬 테스트용, docker-compose 등에서는 ENV 변수로 덮어씀
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        "postgresql+asyncpg://imo_user:imo_pass@localhost:5432/imo_db"
    )
    
    SECRET_KEY: str = os.getenv("JWT_SECRET", "1234567890qwertyuiop")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 # 7 days
    
    class Config:
        case_sensitive = True

settings = Settings()
