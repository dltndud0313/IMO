from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from core.config import settings
from core.database import get_db
from core.exceptions import Unauthorized, UserNotFound
from core.security import decode_access_token
from models.user import User

reusable_oauth2 = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")
optional_oauth2 = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/auth/login",
    auto_error=False,
)


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(reusable_oauth2),
) -> User:
    payload = decode_access_token(token)
    sub = payload.get("sub")
    if not sub:
        raise Unauthorized("Invalid token payload")

    result = await db.execute(select(User).where(User.id == int(sub)))
    user = result.scalar_one_or_none()
    if not user:
        raise UserNotFound()
    return user


async def get_optional_current_user(
    db: AsyncSession = Depends(get_db),
    token: str | None = Depends(optional_oauth2),
) -> User | None:
    if not token:
        return None

    try:
        payload = decode_access_token(token)
        sub = payload.get("sub")
        if not sub:
            return None
        result = await db.execute(select(User).where(User.id == int(sub)))
        return result.scalar_one_or_none()
    except Exception:
        return None
