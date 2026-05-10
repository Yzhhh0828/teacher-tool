"""Analytics endpoints — class overview, exam stats, student trends."""
from __future__ import annotations

from collections import defaultdict
import statistics
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_class_permission, get_current_user
from app.database import get_db
from app.models.exam import Exam, Grade
from app.models.student import Student
from app.models.user import User


router = APIRouter(prefix="/analytics", tags=["analytics"])


def _stats(values: list[float]) -> dict[str, float]:
    if not values:
        return {"count": 0, "mean": 0.0, "median": 0.0, "stdev": 0.0, "min": 0.0, "max": 0.0}
    return {
        "count": len(values),
        "mean": round(statistics.mean(values), 2),
        "median": round(statistics.median(values), 2),
        "stdev": round(statistics.pstdev(values), 2),
        "min": min(values),
        "max": max(values),
    }


@router.get("/class/{class_id}/overview")
async def class_overview(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    await check_class_permission(db, class_id, current_user)

    students = (
        await db.execute(select(Student).where(Student.class_id == class_id))
    ).scalars().all()
    exams = (
        await db.execute(
            select(Exam).where(Exam.class_id == class_id).order_by(Exam.date.desc())
        )
    ).scalars().all()

    # Last exam stats per subject
    last_exam_stats: dict[str, dict[str, float]] = {}
    if exams:
        last = exams[0]
        rows = (
            await db.execute(select(Grade).where(Grade.exam_id == last.id))
        ).scalars().all()
        by_sub: dict[str, list[float]] = defaultdict(list)
        for g in rows:
            by_sub[g.subject].append(g.score)
        last_exam_stats = {sub: _stats(v) for sub, v in by_sub.items()}

    return {
        "class_id": class_id,
        "student_count": len(students),
        "exam_count": len(exams),
        "last_exam": (
            {"id": exams[0].id, "name": exams[0].name, "date": exams[0].date.isoformat(), "stats": last_exam_stats}
            if exams
            else None
        ),
        "gender_split": {
            "male": sum(1 for s in students if s.gender == "male"),
            "female": sum(1 for s in students if s.gender == "female"),
            "other": sum(1 for s in students if s.gender not in ("male", "female")),
        },
    }


@router.get("/exam/{exam_id}/distribution")
async def exam_distribution(
    exam_id: int,
    bucket_size: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    exam = (await db.execute(select(Exam).where(Exam.id == exam_id))).scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
    await check_class_permission(db, exam.class_id, current_user)

    grades = (
        await db.execute(select(Grade).where(Grade.exam_id == exam_id))
    ).scalars().all()
    by_sub: dict[str, list[float]] = defaultdict(list)
    for g in grades:
        by_sub[g.subject].append(g.score)

    distribution: dict[str, dict[str, Any]] = {}
    for sub, vals in by_sub.items():
        # bucket 0..100
        buckets: dict[int, int] = defaultdict(int)
        for v in vals:
            b = int(v // bucket_size) * bucket_size
            buckets[b] += 1
        distribution[sub] = {
            "stats": _stats(vals),
            "buckets": [{"floor": k, "count": buckets[k]} for k in sorted(buckets.keys())],
        }
    return {"exam_id": exam_id, "bucket_size": bucket_size, "subjects": distribution}


@router.get("/student/{student_id}/trend")
async def student_trend(
    student_id: int,
    limit: int = Query(10, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    student = (
        await db.execute(select(Student).where(Student.id == student_id))
    ).scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    await check_class_permission(db, student.class_id, current_user)

    rows = (
        await db.execute(
            select(Grade, Exam)
            .join(Exam, Grade.exam_id == Exam.id)
            .where(Grade.student_id == student_id)
            .order_by(Exam.date.desc())
            .limit(limit * 8)
        )
    ).all()

    by_sub: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for g, e in rows:
        by_sub[g.subject].append(
            {"exam_id": e.id, "exam_name": e.name, "date": e.date.isoformat(), "score": g.score}
        )
    for k in by_sub:
        by_sub[k].sort(key=lambda x: x["date"])
    return {
        "student": {"id": student.id, "name": student.name},
        "subjects": dict(by_sub),
    }


@router.get("/class/{class_id}/compare")
async def compare_class_exams(
    class_id: int,
    subject: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    """Class-mean per exam, optionally filtered by subject."""
    await check_class_permission(db, class_id, current_user)
    exams = (
        await db.execute(
            select(Exam).where(Exam.class_id == class_id).order_by(Exam.date.asc())
        )
    ).scalars().all()
    series: list[dict[str, Any]] = []
    for e in exams:
        q = select(Grade).where(Grade.exam_id == e.id)
        if subject:
            q = q.where(Grade.subject == subject)
        gs = (await db.execute(q)).scalars().all()
        if not gs:
            continue
        scores = [g.score for g in gs]
        series.append(
            {
                "exam_id": e.id,
                "exam_name": e.name,
                "date": e.date.isoformat(),
                "mean": round(statistics.mean(scores), 2),
                "count": len(scores),
            }
        )
    return {"class_id": class_id, "subject": subject, "series": series}
