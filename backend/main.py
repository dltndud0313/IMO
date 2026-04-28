import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from api.routes import auth, exercises, sessions, statistics, users
from core.config import settings
from core.exceptions import APIException
from core.responses import error_response

# 기본 로깅 (uvicorn 이 자체 로거를 따로 가지므로 root 만 INFO 로 둠)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("imo")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 운영 환경은 Alembic (`alembic upgrade head`) 으로 스키마 관리.
    # 컨테이너 entrypoint 에서 마이그레이션을 먼저 실행한 뒤 uvicorn 을 띄운다.
    logger.info("IMO Backend API starting up")
    yield
    logger.info("IMO Backend API shutting down")


app = FastAPI(
    title="IMO Backend API",
    description="Inside Muscle Out - Backend Server utilizing PostgreSQL",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — 환경변수 CORS_ORIGINS 화이트리스트 적용 (기본 "*" 는 개발 편의)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---- 글로벌 에러 핸들러 (명세 §1-3 / §4-2 형식 통일) ----

@app.exception_handler(APIException)
async def api_exception_handler(request: Request, exc: APIException):
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response(exc.code, exc.message),
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    # FastAPI/Starlette HTTPException 을 명세 형식으로 변환
    code = _http_status_to_code(exc.status_code)
    message = exc.detail if isinstance(exc.detail, str) else "HTTP error"
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response(code, message),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Pydantic 입력 검증 실패 → VALIDATION_ERROR
    first = exc.errors()[0] if exc.errors() else {}
    field = ".".join(str(p) for p in first.get("loc", []) if p != "body")
    msg = first.get("msg", "Validation failed")
    message = f"{field}: {msg}" if field else msg
    return JSONResponse(
        status_code=422,
        content=error_response("VALIDATION_ERROR", message),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # 처리되지 않은 예외 → INTERNAL_ERROR
    return JSONResponse(
        status_code=500,
        content=error_response("INTERNAL_ERROR", "Internal server error"),
    )


def _http_status_to_code(status_code: int) -> str:
    return {
        400: "INVALID_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        409: "CONFLICT",
        422: "VALIDATION_ERROR",
        500: "INTERNAL_ERROR",
    }.get(status_code, "INTERNAL_ERROR")


# ---- 라우터 등록 ----
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(sessions.router, prefix="/api/v1/sessions", tags=["Sessions"])
app.include_router(statistics.router, prefix="/api/v1/statistics", tags=["Statistics"])
app.include_router(exercises.router, prefix="/api/v1/exercises", tags=["Exercises"])


@app.get("/")
def read_root():
    return {"message": "Welcome to IMO Backend API."}
