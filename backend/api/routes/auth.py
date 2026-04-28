from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from core.exceptions import DuplicateEmail, Unauthorized
from core.responses import success_response
from core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    get_password_hash,
    verify_password,
)
from models.user import User, UserSettings
from schemas.auth import (
    LoginResponse,
    RefreshRequest,
    RefreshResponse,
    SignupResponse,
    UserCreate,
    UserLogin,
)

router = APIRouter()


@router.post("/signup", status_code=status.HTTP_201_CREATED)
async def signup(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    """API-01 회원가입. 가입과 동시에 토큰 발급."""
    # 이메일 중복 체크
    result = await db.execute(select(User).where(User.email == user_in.email))
    if result.scalar_one_or_none():
        raise DuplicateEmail()

    # 비밀번호 해시 + 유저 생성
    user = User(
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        nickname=user_in.nickname,
    )
    db.add(user)
    await db.flush()  # id 채번

    # 기본 설정 레코드
    db.add(UserSettings(user_id=user.id))
    await db.commit()

    # 토큰 발급 후 명세 SignupResponse 반환
    access = create_access_token(subject=user.id)
    refresh = create_refresh_token(subject=user.id)
    payload = SignupResponse(
        user_id=user.id,
        email=user.email,
        nickname=user.nickname,
        access_token=access,
        refresh_token=refresh,
    )
    return success_response(payload.model_dump(by_alias=True))


@router.post("/login")
async def login(user_in: UserLogin, db: AsyncSession = Depends(get_db)):
    """API-02 로그인."""
    result = await db.execute(select(User).where(User.email == user_in.email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(user_in.password, user.hashed_password):
        raise Unauthorized("Incorrect email or password")

    access = create_access_token(subject=user.id)
    refresh = create_refresh_token(subject=user.id)
    payload = LoginResponse(
        user_id=user.id,
        access_token=access,
        refresh_token=refresh,
    )
    return success_response(payload.model_dump(by_alias=True))


@router.post("/refresh")
async def refresh_token(request: RefreshRequest):
    """API-03 토큰 갱신. refresh 검증 후 access + refresh 모두 새로 발급(rotation)."""
    payload = decode_refresh_token(request.refresh_token)
    sub = payload.get("sub")
    if not sub:
        raise Unauthorized("Invalid refresh token payload")

    new_access = create_access_token(subject=sub)
    new_refresh = create_refresh_token(subject=sub)
    body = RefreshResponse(access_token=new_access, refresh_token=new_refresh)
    return success_response(body.model_dump(by_alias=True))
