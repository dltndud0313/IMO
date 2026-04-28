from pydantic import EmailStr, Field

from schemas._base import CamelModel


# ==== 요청 ====
class UserCreate(CamelModel):
    email: EmailStr
    password: str = Field(min_length=8)
    nickname: str = Field(min_length=1, max_length=20)


class UserLogin(CamelModel):
    email: EmailStr
    password: str


class RefreshRequest(CamelModel):
    refresh_token: str


# ==== 응답 ====
class SignupResponse(CamelModel):
    user_id: int
    email: EmailStr
    nickname: str
    access_token: str
    refresh_token: str


class LoginResponse(CamelModel):
    user_id: int
    access_token: str
    refresh_token: str


class RefreshResponse(CamelModel):
    access_token: str
    refresh_token: str
