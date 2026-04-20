from datetime import datetime, timedelta, timezone
import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.class_ import Class, ClassMember
from app.schemas.class_ import (
    ClassCreate, ClassUpdate, ClassResponse, ClassDetailResponse,
    InviteCodeResponse, JoinClassRequest,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/classes", tags=["classes"])


def generate_invite_code() -> str:
    return secrets.token_urlsafe(8)


@router.post("", response_model=ClassResponse)
async def create_class(
    data: ClassCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    class_ = Class(name=data.name, grade=data.grade, owner_id=current_user.id)
    class_.members.append(ClassMember(user_id=current_user.id, role="owner"))
    db.add(class_)
    await db.commit()
    await db.refresh(class_)
    return class_


@router.get("")
async def list_classes(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Get classes where user is owner or member
    result = await db.execute(
        select(Class)
        .join(ClassMember, Class.id == ClassMember.class_id)
        .where(ClassMember.user_id == current_user.id)
    )
    classes = result.scalars().all()
    return classes


@router.get("/{class_id}", response_model=ClassDetailResponse)
async def get_class(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check membership
    member_result = await db.execute(
        select(ClassMember)
        .where(ClassMember.class_id == class_id, ClassMember.user_id == current_user.id)
    )
    if not member_result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not a member of this class")

    result = await db.execute(
        select(Class)
        .options(selectinload(Class.members))
        .where(Class.id == class_id)
    )
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    return class_


@router.put("/{class_id}", response_model=ClassResponse)
async def update_class(
    class_id: int,
    data: ClassUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Class).where(Class.id == class_id))
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    if class_.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can update class")

    if data.name is not None:
        class_.name = data.name
    if data.grade is not None:
        class_.grade = data.grade

    await db.commit()
    await db.refresh(class_)
    return class_


@router.delete("/{class_id}")
async def delete_class(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Class).where(Class.id == class_id))
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    if class_.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can delete class")

    await db.delete(class_)
    await db.commit()
    return {"message": "Class deleted"}


@router.post("/{class_id}/invite_code", response_model=InviteCodeResponse)
async def create_invite_code(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Class).where(Class.id == class_id))
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    if class_.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can create invite code")

    invite_code = generate_invite_code()
    expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

    class_.invite_code = invite_code
    class_.invite_expires_at = expires_at

    await db.commit()
    return InviteCodeResponse(invite_code=invite_code, expires_at=expires_at)


@router.post("/join")
async def join_class(
    data: JoinClassRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Find class by invite code
    result = await db.execute(
        select(Class).where(
            Class.invite_code == data.invite_code,
            Class.invite_expires_at > datetime.now(timezone.utc),
        )
    )
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Invalid or expired invite code")

    # Check if already a member
    member_result = await db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_.id,
            ClassMember.user_id == current_user.id,
        )
    )
    if member_result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Already a member")

    # Add as teacher
    member = ClassMember(
        class_id=class_.id,
        user_id=current_user.id,
        role="teacher",
        subject=data.subject,
    )
    db.add(member)
    await db.commit()

    return {"message": "Joined class successfully"}
