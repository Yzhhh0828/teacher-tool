"""Grade tools: list, add, bulk upsert."""
from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.tools.registry import registry
from app.agent.audit import log_action
from app.mcp.tools import MCPTools
from app.models.exam import Exam, Grade
from app.models.student import Student


@registry.tool(
    name="list_grades",
    description="列出某次考试下所有学生的成绩（只读）。",
    parameters={
        "type": "object",
        "properties": {"exam_id": {"type": "integer"}},
        "required": ["exam_id"],
    },
    category="grade",
)
async def list_grades(*, db: AsyncSession, user_id: int, exam_id: int) -> dict[str, Any]:
    items = await MCPTools(db, user_id).get_grades(exam_id)
    return {"exam_id": exam_id, "count": len(items), "items": items}


@registry.tool(
    name="add_grade",
    description="为单个学生录入或覆盖单科成绩。需要用户确认。",
    parameters={
        "type": "object",
        "properties": {
            "exam_id": {"type": "integer"},
            "student_id": {"type": "integer"},
            "subject": {"type": "string"},
            "score": {"type": "number"},
        },
        "required": ["exam_id", "student_id", "subject", "score"],
    },
    requires_confirmation=True,
    category="grade",
)
async def add_grade(
    *, db: AsyncSession, user_id: int, exam_id: int, student_id: int, subject: str, score: float
) -> dict[str, Any]:
    result = await MCPTools(db, user_id).add_grade(exam_id, student_id, subject, score)
    await log_action(
        db,
        user_id=user_id,
        action_type="add_grade",
        payload={"exam_id": exam_id, "student_id": student_id, "subject": subject, "score": score},
        diff={"created": 1},
        undo_payload={"created_grade_id": result.get("id")} if isinstance(result, dict) else {},
    )
    return result


@registry.tool(
    name="bulk_upsert_grades",
    description=(
        "批量录入/更新成绩。每条 item 可用 student_id 或 student_name 定位学生。"
        "返回 diff（新增/更新/跳过 行数）。需要用户确认。"
    ),
    parameters={
        "type": "object",
        "properties": {
            "exam_id": {"type": "integer"},
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "student_id": {"type": "integer"},
                        "student_name": {"type": "string"},
                        "subject": {"type": "string"},
                        "score": {"type": "number"},
                    },
                    "required": ["subject", "score"],
                },
            },
        },
        "required": ["exam_id", "items"],
    },
    requires_confirmation=True,
    category="grade",
)
async def bulk_upsert_grades(
    *, db: AsyncSession, user_id: int, exam_id: int, items: list[dict[str, Any]]
) -> dict[str, Any]:
    mcp = MCPTools(db, user_id)
    exam = (await db.execute(select(Exam).where(Exam.id == exam_id))).scalar_one_or_none()
    if not exam:
        raise ValueError("Exam not found")
    await mcp.check_class_permission(exam.class_id)

    students = (
        await db.execute(select(Student).where(Student.class_id == exam.class_id))
    ).scalars().all()
    by_id = {s.id: s for s in students}
    by_name = {s.name: s for s in students}

    created_rows: list[Grade] = []
    updated_snapshots: list[dict[str, Any]] = []
    skipped = 0
    skipped_reasons: list[str] = []

    for it in items:
        sid = it.get("student_id")
        sname = (it.get("student_name") or "").strip()
        student = by_id.get(sid) if sid else (by_name.get(sname) if sname else None)
        if student is None:
            skipped += 1
            skipped_reasons.append(f"student not found: {sid or sname}")
            continue
        subject = it.get("subject")
        score = it.get("score")
        if subject is None or score is None:
            skipped += 1
            skipped_reasons.append(f"missing subject/score for {student.name}")
            continue

        existing = (
            await db.execute(
                select(Grade).where(
                    Grade.exam_id == exam_id,
                    Grade.student_id == student.id,
                    Grade.subject == subject,
                )
            )
        ).scalar_one_or_none()
        if existing:
            updated_snapshots.append({"id": existing.id, "score": existing.score})
            existing.score = float(score)
        else:
            row = Grade(exam_id=exam_id, student_id=student.id, subject=subject, score=float(score))
            db.add(row)
            created_rows.append(row)

    await db.commit()
    for row in created_rows:
        await db.refresh(row)
    diff = {
        "created": len(created_rows),
        "updated": len(updated_snapshots),
        "skipped": skipped,
        "reasons": skipped_reasons[:20],
    }
    await log_action(
        db,
        user_id=user_id,
        action_type="bulk_upsert_grades",
        payload={"exam_id": exam_id, "count": len(items)},
        diff=diff,
        undo_payload={
            "created_grade_ids": [r.id for r in created_rows],
            "updated_grade_snapshots": updated_snapshots,
        },
    )
    return diff
