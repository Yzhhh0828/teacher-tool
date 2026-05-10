"""Analytics tools — pure read-only aggregations the LLM can call."""
from __future__ import annotations

import statistics
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.tools.registry import registry
from app.mcp.tools import MCPTools
from app.models.exam import Exam, Grade
from app.models.student import Student


@registry.tool(
    name="analyze_class_performance",
    description=(
        "聚合某次考试的全班表现：均值、中位数、方差、各科分布、最高/最低分。"
    ),
    parameters={
        "type": "object",
        "properties": {
            "class_id": {"type": "integer"},
            "exam_id": {"type": "integer"},
        },
        "required": ["class_id", "exam_id"],
    },
    category="analytics",
)
async def analyze_class_performance(
    *, db: AsyncSession, user_id: int, class_id: int, exam_id: int
) -> dict[str, Any]:
    mcp = MCPTools(db, user_id)
    await mcp.check_class_permission(class_id)
    exam = (await db.execute(select(Exam).where(Exam.id == exam_id))).scalar_one_or_none()
    if not exam or exam.class_id != class_id:
        raise ValueError("Exam not found in class")

    rows = (
        await db.execute(
            select(Grade, Student)
            .join(Student, Grade.student_id == Student.id)
            .where(Grade.exam_id == exam_id)
        )
    ).all()

    by_subject: dict[str, list[float]] = {}
    by_student: dict[str, float] = {}
    for g, s in rows:
        by_subject.setdefault(g.subject, []).append(g.score)
        by_student[s.name] = by_student.get(s.name, 0.0) + g.score

    def stats(values: list[float]) -> dict[str, float]:
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

    return {
        "exam": {"id": exam.id, "name": exam.name},
        "subjects": {sub: stats(v) for sub, v in by_subject.items()},
        "total_score_top5": sorted(by_student.items(), key=lambda x: -x[1])[:5],
        "total_score_bottom5": sorted(by_student.items(), key=lambda x: x[1])[:5],
        "student_count": len(by_student),
    }


@registry.tool(
    name="student_trend",
    description="单个学生在最近 N 次考试中各科分数的趋势。",
    parameters={
        "type": "object",
        "properties": {
            "student_id": {"type": "integer"},
            "limit": {"type": "integer", "default": 10},
        },
        "required": ["student_id"],
    },
    category="analytics",
)
async def student_trend(
    *, db: AsyncSession, user_id: int, student_id: int, limit: int = 10
) -> dict[str, Any]:
    student = (
        await db.execute(select(Student).where(Student.id == student_id))
    ).scalar_one_or_none()
    if not student:
        raise ValueError("Student not found")
    await MCPTools(db, user_id).check_class_permission(student.class_id)

    rows = (
        await db.execute(
            select(Grade, Exam)
            .join(Exam, Grade.exam_id == Exam.id)
            .where(Grade.student_id == student_id)
            .order_by(Exam.date.desc())
            .limit(limit * 6)  # accommodate multiple subjects per exam
        )
    ).all()

    series: dict[str, list[dict[str, Any]]] = {}
    for g, e in rows:
        series.setdefault(g.subject, []).append(
            {"exam_id": e.id, "exam_name": e.name, "date": e.date.isoformat(), "score": g.score}
        )
    for k in series:
        series[k].sort(key=lambda x: x["date"])
    return {"student": {"id": student.id, "name": student.name}, "series": series}
