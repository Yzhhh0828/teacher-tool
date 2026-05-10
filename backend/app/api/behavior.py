"""Student behavior tracking API — categories, records, and leaderboard."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, check_class_permission
from app.database import get_db
from app.models.behavior import BehaviorCategory, BehaviorRecord
from app.models.student import Student
from app.models.user import User
from app.schemas.behavior import (
    CategoryCreate,
    CategoryResponse,
    CategoryUpdate,
    RecordCreate,
    RecordResponse,
    StudentScore,
)

router = APIRouter(prefix="/behavior", tags=["behavior"])

# ─── Preset seed data ────────────────────────────────────────────────────────

PRESET_CATEGORIES: list[dict] = [
    {"name": "回答问题", "icon": "lightbulb", "score": 2, "sort_order": 1},
    {"name": "作业优秀", "icon": "star", "score": 3, "sort_order": 2},
    {"name": "助人为乐", "icon": "handshake", "score": 2, "sort_order": 3},
    {"name": "课堂表现好", "icon": "thumb_up", "score": 1, "sort_order": 4},
    {"name": "迟到", "icon": "alarm", "score": -1, "sort_order": 5},
    {"name": "未交作业", "icon": "assignment_late", "score": -2, "sort_order": 6},
    {"name": "课堂违纪", "icon": "warning", "score": -2, "sort_order": 7},
    {"name": "其他扣分", "icon": "remove_circle", "score": -1, "sort_order": 8},
]


async def _ensure_presets(db: AsyncSession, class_id: int) -> None:
    """Seed preset categories for a class if none exist yet."""
    count = (
        await db.execute(
            select(func.count())
            .select_from(BehaviorCategory)
            .where(BehaviorCategory.class_id == class_id, BehaviorCategory.is_preset == True)
        )
    ).scalar() or 0
    if count > 0:
        return
    for p in PRESET_CATEGORIES:
        db.add(BehaviorCategory(class_id=class_id, is_preset=True, **p))
    await db.flush()


# ─── Categories ───────────────────────────────────────────────────────────────

@router.get("/categories/class/{class_id}", response_model=list[CategoryResponse])
async def list_categories(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)
    await _ensure_presets(db, class_id)
    rows = (
        await db.execute(
            select(BehaviorCategory)
            .where(BehaviorCategory.class_id == class_id)
            .order_by(BehaviorCategory.sort_order)
        )
    ).scalars().all()
    return rows


@router.post("/categories/class/{class_id}", response_model=CategoryResponse)
async def create_category(
    class_id: int,
    data: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)
    cat = BehaviorCategory(
        class_id=class_id,
        name=data.name,
        icon=data.icon,
        score=data.score,
        sort_order=data.sort_order,
        is_preset=False,
    )
    db.add(cat)
    await db.flush()
    await db.refresh(cat)
    return cat


@router.put("/categories/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: int,
    data: CategoryUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    cat = (await db.execute(select(BehaviorCategory).where(BehaviorCategory.id == category_id))).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await check_class_permission(db, cat.class_id, current_user)
    if data.name is not None:
        cat.name = data.name
    if data.icon is not None:
        cat.icon = data.icon
    if data.score is not None:
        cat.score = data.score
    if data.sort_order is not None:
        cat.sort_order = data.sort_order
    await db.flush()
    await db.refresh(cat)
    return cat


@router.delete("/categories/{category_id}")
async def delete_category(
    category_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    cat = (await db.execute(select(BehaviorCategory).where(BehaviorCategory.id == category_id))).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await check_class_permission(db, cat.class_id, current_user)
    await db.delete(cat)
    await db.flush()
    return {"message": "Category deleted"}


# ─── Records ─────────────────────────────────────────────────────────────────

@router.post("/records/class/{class_id}", response_model=list[RecordResponse])
async def create_records(
    class_id: int,
    data: RecordCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create behavior records for one or more students at once."""
    await check_class_permission(db, class_id, current_user)

    cat = (await db.execute(select(BehaviorCategory).where(BehaviorCategory.id == data.category_id))).scalar_one_or_none()
    if not cat or cat.class_id != class_id:
        raise HTTPException(status_code=404, detail="Category not found in this class")

    # Validate all students belong to this class
    students = (
        await db.execute(select(Student).where(Student.id.in_(data.student_ids), Student.class_id == class_id))
    ).scalars().all()
    found_ids = {s.id for s in students}
    missing = set(data.student_ids) - found_ids
    if missing:
        raise HTTPException(status_code=400, detail=f"Students not in class: {missing}")

    student_map = {s.id: s.name for s in students}
    records = []
    for sid in data.student_ids:
        rec = BehaviorRecord(
            class_id=class_id,
            student_id=sid,
            category_id=cat.id,
            user_id=current_user.id,
            score=cat.score,
            note=data.note,
        )
        db.add(rec)
        records.append((rec, student_map[sid]))

    await db.flush()
    result = []
    for rec, sname in records:
        await db.refresh(rec)
        result.append(RecordResponse(
            id=rec.id,
            class_id=rec.class_id,
            student_id=rec.student_id,
            category_id=rec.category_id,
            user_id=rec.user_id,
            score=rec.score,
            note=rec.note,
            created_at=rec.created_at,
            category_name=cat.name,
            student_name=sname,
        ))
    return result


@router.get("/records/class/{class_id}", response_model=list[RecordResponse])
async def list_class_records(
    class_id: int,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    student_id: int | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)
    q = (
        select(BehaviorRecord, BehaviorCategory.name, Student.name)
        .join(BehaviorCategory, BehaviorRecord.category_id == BehaviorCategory.id)
        .join(Student, BehaviorRecord.student_id == Student.id)
        .where(BehaviorRecord.class_id == class_id)
    )
    if student_id is not None:
        q = q.where(BehaviorRecord.student_id == student_id)
    q = q.order_by(BehaviorRecord.created_at.desc()).offset(offset).limit(limit)
    rows = (await db.execute(q)).all()
    return [
        RecordResponse(
            id=rec.id,
            class_id=rec.class_id,
            student_id=rec.student_id,
            category_id=rec.category_id,
            user_id=rec.user_id,
            score=rec.score,
            note=rec.note,
            created_at=rec.created_at,
            category_name=cat_name,
            student_name=stu_name,
        )
        for rec, cat_name, stu_name in rows
    ]


@router.delete("/records/{record_id}")
async def delete_record(
    record_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rec = (await db.execute(select(BehaviorRecord).where(BehaviorRecord.id == record_id))).scalar_one_or_none()
    if not rec:
        raise HTTPException(status_code=404, detail="Record not found")
    await check_class_permission(db, rec.class_id, current_user)
    await db.delete(rec)
    await db.flush()
    return {"message": "Record deleted"}


# ─── Stats / Leaderboard ─────────────────────────────────────────────────────

@router.get("/stats/class/{class_id}", response_model=list[StudentScore])
async def class_leaderboard(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await check_class_permission(db, class_id, current_user)
    rows = (
        await db.execute(
            select(
                Student.id,
                Student.name,
                func.coalesce(func.sum(BehaviorRecord.score), 0).label("total"),
                func.count(BehaviorRecord.id).label("cnt"),
            )
            .outerjoin(BehaviorRecord, BehaviorRecord.student_id == Student.id)
            .where(Student.class_id == class_id)
            .group_by(Student.id, Student.name)
            .order_by(func.coalesce(func.sum(BehaviorRecord.score), 0).desc())
        )
    ).all()
    return [
        StudentScore(student_id=r[0], student_name=r[1], total_score=float(r[2]), record_count=r[3])
        for r in rows
    ]
