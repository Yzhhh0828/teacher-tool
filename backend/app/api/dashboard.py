"""Dashboard aggregation endpoint — returns class overview metrics."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.database import get_db
from app.models.user import User
from app.models.student import Student
from app.models.exam import Exam, Grade
from app.models.schedule import Schedule
from app.models.seating import Seating
from app.api.deps import get_current_user, check_class_permission

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/class/{class_id}")
async def class_dashboard(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)

    # Student count
    student_count_q = await db.execute(
        select(func.count()).select_from(Student).where(Student.class_id == class_id)
    )
    student_count = student_count_q.scalar() or 0

    male_count_q = await db.execute(
        select(func.count()).select_from(Student).where(
            Student.class_id == class_id, Student.gender == "male"
        )
    )
    male_count = male_count_q.scalar() or 0

    # Exam count + latest exam
    exam_count_q = await db.execute(
        select(func.count()).select_from(Exam).where(Exam.class_id == class_id)
    )
    exam_count = exam_count_q.scalar() or 0

    latest_exam_q = await db.execute(
        select(Exam).where(Exam.class_id == class_id).order_by(Exam.date.desc()).limit(1)
    )
    latest_exam = latest_exam_q.scalar_one_or_none()

    # Grade stats for latest exam
    avg_score = None
    grade_entry_count = 0
    if latest_exam:
        avg_q = await db.execute(
            select(func.avg(Grade.score), func.count()).where(Grade.exam_id == latest_exam.id)
        )
        row = avg_q.one()
        avg_score = round(float(row[0]), 1) if row[0] is not None else None
        grade_entry_count = row[1] or 0

    # Schedule fill: how many slots filled out of 7*10=70
    schedule_count_q = await db.execute(
        select(func.count()).select_from(Schedule).where(Schedule.class_id == class_id)
    )
    schedule_count = schedule_count_q.scalar() or 0

    # Seating fill
    seating_q = await db.execute(
        select(Seating).where(Seating.class_id == class_id)
    )
    seating = seating_q.scalar_one_or_none()
    seating_filled = 0
    seating_total = 0
    if seating and seating.seats:
        for row in seating.seats:
            if isinstance(row, list):
                seating_total += len(row)
                seating_filled += sum(1 for c in row if c is not None)

    return {
        "student_count": student_count,
        "male_count": male_count,
        "female_count": student_count - male_count,
        "exam_count": exam_count,
        "latest_exam_name": latest_exam.name if latest_exam else None,
        "latest_exam_avg": avg_score,
        "grade_entry_count": grade_entry_count,
        "schedule_count": schedule_count,
        "schedule_fill_rate": round(schedule_count / 70 * 100, 1) if schedule_count else 0,
        "seating_filled": seating_filled,
        "seating_total": seating_total,
    }
