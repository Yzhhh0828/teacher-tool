from datetime import timedelta
import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.config import settings
from app.models.user import User
from app.schemas.auth import SendCodeRequest, LoginRequest, TokenResponse, RefreshTokenRequest
from app.schemas.user import UserResponse
from app.core.security import (
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.core.verification_codes import VerificationCodeStore
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

verification_store = VerificationCodeStore(
    ttl=timedelta(seconds=settings.VERIFICATION_CODE_TTL_SECONDS),
)


@router.post("/send_code")
async def send_code(request: SendCodeRequest, db: AsyncSession = Depends(get_db)):
    # 检查用户是否存在，不存在则创建
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()

    if user is None:
        # Keep password unpredictable even when phone login creates the user.
        user = User(
            phone=request.phone,
            password_hash=get_password_hash(secrets.token_urlsafe(32)),
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    fixed_code = (
        settings.DEV_FIXED_VERIFICATION_CODE
        if settings.should_expose_debug_verification_code
        else None
    )
    code = verification_store.issue_code(request.phone, fixed_code=fixed_code)

    response = {"message": "Code sent"}
    if settings.should_expose_debug_verification_code:
        response["debug_code"] = code

    return response


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    # 验证验证码
    if not verification_store.verify_code(request.phone, request.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code",
        )

    # 获取用户
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # 生成 Token
    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: RefreshTokenRequest):
    payload = decode_token(request.refresh_token)

    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token payload",
        )

    access_token = create_access_token(data={"sub": user_id})
    new_refresh_token = create_refresh_token(data={"sub": user_id})

    return TokenResponse(access_token=access_token, refresh_token=new_refresh_token)


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return user
