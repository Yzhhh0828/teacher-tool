from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import ClassMember
from app.models.schedule import Schedule
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate, ScheduleResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/schedules", tags=["schedules"])


async def check_class_permission(db: AsyncSession, class_id: int, user: User):
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
    return member


@router.post("", response_model=ScheduleResponse)
async def create_schedule(
    data: ScheduleCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, data.class_id, current_user)

    schedule = Schedule(**data.model_dump())
    db.add(schedule)
    await db.commit()
    await db.refresh(schedule)
    return schedule


@router.get("/class/{class_id}")
async def list_schedules(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)

    result = await db.execute(
        select(Schedule)
        .where(Schedule.class_id == class_id)
        .order_by(Schedule.day_of_week, Schedule.period)
    )
    schedules = result.scalars().all()
    return schedules


@router.delete("/{schedule_id}")
async def delete_schedule(
    schedule_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()

    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    await check_class_permission(db, schedule.class_id, current_user)

    await db.delete(schedule)
    await db.commit()
    return {"message": "Schedule deleted"}
