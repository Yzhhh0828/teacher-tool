from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import Class, ClassMember
from app.models.exam import Exam, Grade
from app.models.student import Student
from app.schemas.exam import ExamCreate, ExamUpdate, ExamResponse, GradeCreate, GradeUpdate, GradeResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/grades", tags=["grades"])


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


# Exam endpoints
@router.post("/exams", response_model=ExamResponse)
async def create_exam(
    data: ExamCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, data.class_id, current_user, require_owner=True)

    exam = Exam(**data.model_dump())
    db.add(exam)
    await db.commit()
    await db.refresh(exam)
    return exam


@router.get("/exams/class/{class_id}")
async def list_exams(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)

    result = await db.execute(
        select(Exam).where(Exam.class_id == class_id).order_by(Exam.date.desc())
    )
    exams = result.scalars().all()
    return exams


@router.delete("/exams/{exam_id}")
async def delete_exam(
    exam_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Exam).where(Exam.id == exam_id))
    exam = result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    await check_class_permission(db, exam.class_id, current_user, require_owner=True)

    await db.delete(exam)
    await db.commit()
    return {"message": "Exam deleted"}


# Grade endpoints
@router.post("", response_model=GradeResponse)
async def create_grade(
    data: GradeCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Get exam and check permission
    result = await db.execute(select(Exam).where(Exam.id == data.exam_id))
    exam = result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    member = await check_class_permission(db, exam.class_id, current_user)

    # For teachers, check subject matches
    if member.role == "teacher" and member.subject != data.subject:
        raise HTTPException(status_code=403, detail="Cannot add grade for this subject")

    # Check if grade already exists
    existing_result = await db.execute(
        select(Grade).where(
            Grade.exam_id == data.exam_id,
            Grade.student_id == data.student_id,
            Grade.subject == data.subject,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        existing.score = data.score
        grade = existing
    else:
        grade = Grade(**data.model_dump())
        db.add(grade)

    await db.commit()
    await db.refresh(grade)
    return grade


@router.get("/exams/{exam_id}")
async def list_grades(
    exam_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Exam).where(Exam.id == exam_id))
    exam = result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    await check_class_permission(db, exam.class_id, current_user)

    result = await db.execute(
        select(Grade).where(Grade.exam_id == exam_id).order_by(Grade.student_id)
    )
    grades = result.scalars().all()
    return grades


@router.put("/{grade_id}", response_model=GradeResponse)
async def update_grade(
    grade_id: int,
    data: GradeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Grade).where(Grade.id == grade_id))
    grade = result.scalar_one_or_none()

    if not grade:
        raise HTTPException(status_code=404, detail="Grade not found")

    # Get exam for class permission check
    exam_result = await db.execute(select(Exam).where(Exam.id == grade.exam_id))
    exam = exam_result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    member = await check_class_permission(db, exam.class_id, current_user)

    # Teachers can only update grades in their own subject.
    if member.role == "teacher" and member.subject != grade.subject:
        raise HTTPException(status_code=403, detail="Cannot update grade for this subject")

    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(grade, key, value)

    await db.commit()
    await db.refresh(grade)
    return grade


@router.delete("/{grade_id}")
async def delete_grade(
    grade_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Grade).where(Grade.id == grade_id))
    grade = result.scalar_one_or_none()

    if not grade:
        raise HTTPException(status_code=404, detail="Grade not found")

    exam_result = await db.execute(select(Exam).where(Exam.id == grade.exam_id))
    exam = exam_result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    await check_class_permission(db, exam.class_id, current_user, require_owner=True)

    await db.delete(grade)
    await db.commit()
    return {"message": "Grade deleted"}