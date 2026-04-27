from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.database import get_db
from models.user import User, UserSettings
from core.security import verify_password, get_password_hash, create_access_token
from schemas.auth import UserCreate, UserLogin, TokenResponse
from schemas.user import UserProfileResponse

router = APIRouter()

@router.post("/signup", status_code=status.HTTP_201_CREATED)
async def signup(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    # 이메일 중복 체크
    result = await db.execute(select(User).where(User.email == user_in.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The user with this username already exists in the system.",
        )
    
    # 비밀번호 해시 및 유저 생성
    user = User(
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        nickname=user_in.nickname
    )
    db.add(user)
    await db.flush() # DB에서 id 채번을 받기위해 flush
    
    # 기본 프로필 세팅 레코드 생성
    default_settings = UserSettings(user_id=user.id)
    db.add(default_settings)
    
    await db.commit()
    return {"success": True, "message": "User registered successfully"}

@router.post("/login", response_model=TokenResponse)
async def login(user_in: UserLogin, db: AsyncSession = Depends(get_db)):
    # 유저 조회
    result = await db.execute(select(User).where(User.email == user_in.email))
    user = result.scalar_one_or_none()
    
    # 인증 실패
    if not user or not verify_password(user_in.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
        
    # 토큰 발급
    access_token = create_access_token(subject=user.id)
    
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    request: RefreshRequest,
    db: AsyncSession = Depends(get_db)
):
    try:
        from core.security import ALGORITHM
        from jose import jwt, JWTError
        from core.config import settings
        
        payload = jwt.decode(
            request.refresh_token, settings.SECRET_KEY, algorithms=[ALGORITHM] # 시크릿 공유
        )
        token_uid = payload.get("sub")
        if not token_uid: raise JWTError()
    except (JWTError):
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    access_token = create_access_token(subject=token_uid)
    return {"access_token": access_token, "token_type": "bearer"}

