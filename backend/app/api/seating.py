import random
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import ClassMember
from app.models.seating import Seating
from app.models.student import Student
from app.schemas.seating import SeatingUpdate, SeatingResponse, ShuffleResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/seating", tags=["seating"])


async def check_class_permission(db: AsyncSession, class_id: int, user: User, require_owner: bool = False):
    """Check if user has permission to access class"""
    result = await db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_id,
            ClassMember.user_id == user.id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this class")
    if require_owner and member.role != "owner":
        raise HTTPException(status_code=403, detail="Only owner can perform this action")
    return member


def create_default_seats(rows: int, cols: int, student_ids: list) -> list:
    """Create a 2D seat array"""
    seats = []
    student_iter = iter(student_ids)
    for _ in range(rows):
        row = []
        for _ in range(cols):
            try:
                row.append(next(student_iter))
            except StopIteration:
                row.append(None)
        seats.append(row)
    return seats


@router.get("/class/{class_id}", response_model=SeatingResponse)
async def get_seating(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)

    result = await db.execute(select(Seating).where(Seating.class_id == class_id))
    seating = result.scalar_one_or_none()

    if not seating:
        # Create default seating
        student_result = await db.execute(
            select(Student).where(Student.class_id == class_id)
        )
        students = student_result.scalars().all()
        student_ids = [s.id for s in students]

        seats = create_default_seats(6, 8, student_ids)
        seating = Seating(class_id=class_id, rows=6, cols=8, seats=seats)
        db.add(seating)
        await db.commit()
        await db.refresh(seating)

    return seating


@router.put("/class/{class_id}", response_model=SeatingResponse)
async def update_seating(
    class_id: int,
    data: SeatingUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user, require_owner=True)

    result = await db.execute(select(Seating).where(Seating.class_id == class_id))
    seating = result.scalar_one_or_none()

    if not seating:
        seating = Seating(class_id=class_id)
        db.add(seating)

    if data.rows is not None:
        seating.rows = data.rows
    if data.cols is not None:
        seating.cols = data.cols
    if data.seats is not None:
        seating.seats = data.seats

    await db.commit()
    await db.refresh(seating)
    return seating


@router.post("/class/{class_id}/shuffle", response_model=ShuffleResponse)
async def shuffle_seats(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user, require_owner=True)

    result = await db.execute(select(Seating).where(Seating.class_id == class_id))
    seating = result.scalar_one_or_none()

    if not seating:
        raise HTTPException(status_code=404, detail="Seating not found")

    # Get all student IDs
    student_result = await db.execute(
        select(Student).where(Student.class_id == class_id)
    )
    students = student_result.scalars().all()
    student_ids = [s.id for s in students]

    # Shuffle
    random.shuffle(student_ids)

    # Create new seat arrangement
    seats = create_default_seats(seating.rows, seating.cols, student_ids)
    seating.seats = seats

    await db.commit()
    await db.refresh(seating)

    return ShuffleResponse(success=True, seats=seats)