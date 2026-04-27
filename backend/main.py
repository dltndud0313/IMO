from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.database import engine, Base
from api.routes import sessions, auth, users
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # DB 스키마 생성 (운영 환경에서는 Alembic 등의 마이그레이션 도구 사용 권장)
    async with engine.begin() as conn:
        # await conn.run_sync(Base.metadata.drop_all) # 개발 테스트 시
        await conn.run_sync(Base.metadata.create_all)
    yield

app = FastAPI(
    title="IMO Backend API",
    description="Inside Muscle Out - Backend Server utilizing PostgreSQL",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 설정 (앱에서의 통신 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # 배포 시 EC2 도메인이나 앱 IP로 제한 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API 라우터 등록
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(sessions.router, prefix="/api/v1/sessions", tags=["Sessions"])

@app.get("/")
def read_root():
    return {"message": "Welcome to IMO Backend API."}
