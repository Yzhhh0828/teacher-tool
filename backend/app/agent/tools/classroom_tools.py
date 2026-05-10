"""Classroom front-stage tools — pick / group / log."""
from __future__ import annotations

import random
from datetime import datetime, UTC, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.tools.registry import registry
from app.mcp.tools import MCPTools
from app.models.classroom import ClassroomEvent
from app.models.student import Student


@registry.tool(
    name="pick_random_student",
    description="从班级中随机抽取一名学生用于点名，可选启用近期防重复。",
    parameters={
        "type": "object",
        "properties": {
            "class_id": {"type": "integer"},
            "avoid_recent_minutes": {"type": "integer", "default": 60},
        },
        "required": ["class_id"],
    },
    category="classroom",
)
async def pick_random_student(
    *, db: AsyncSession, user_id: int, class_id: int, avoid_recent_minutes: int = 60
) -> dict[str, Any]:
    await MCPTools(db, user_id).check_class_permission(class_id)
    students = (
        await db.execute(select(Student).where(Student.class_id == class_id))
    ).scalars().all()
    if not students:
        return {"picked": None, "reason": "no students"}

    cutoff = datetime.now(UTC) - timedelta(minutes=max(0, avoid_recent_minutes))
    recent = (
        await db.execute(
            select(ClassroomEvent).where(
                ClassroomEvent.class_id == class_id,
                ClassroomEvent.event_type == "pick",
                ClassroomEvent.created_at >= cutoff,
            )
        )
    ).scalars().all()
    recent_ids = {ev.payload.get("student_id") for ev in recent if isinstance(ev.payload, dict)}
    pool = [s for s in students if s.id not in recent_ids] or list(students)
    chosen = random.choice(pool)

    db.add(
        ClassroomEvent(
            class_id=class_id,
            user_id=user_id,
            event_type="pick",
            payload={"student_id": chosen.id, "student_name": chosen.name},
        )
    )
    await db.commit()
    return {"picked": {"id": chosen.id, "name": chosen.name, "gender": chosen.gender}}


@registry.tool(
    name="random_groups",
    description="把班级学生随机分组。可指定每组人数或组数。",
    parameters={
        "type": "object",
        "properties": {
            "class_id": {"type": "integer"},
            "group_size": {"type": "integer"},
            "group_count": {"type": "integer"},
            "shuffle_seed": {"type": "integer"},
        },
        "required": ["class_id"],
    },
    category="classroom",
)
async def random_groups(
    *,
    db: AsyncSession,
    user_id: int,
    class_id: int,
    group_size: int | None = None,
    group_count: int | None = None,
    shuffle_seed: int | None = None,
) -> dict[str, Any]:
    await MCPTools(db, user_id).check_class_permission(class_id)
    students = (
        await db.execute(select(Student).where(Student.class_id == class_id))
    ).scalars().all()
    items = [{"id": s.id, "name": s.name} for s in students]

    rng = random.Random(shuffle_seed) if shuffle_seed is not None else random
    rng.shuffle(items)

    if group_count and group_count > 0:
        groups: list[list[dict[str, Any]]] = [[] for _ in range(group_count)]
        for i, it in enumerate(items):
            groups[i % group_count].append(it)
    else:
        size = max(1, group_size or 4)
        groups = [items[i : i + size] for i in range(0, len(items), size)]

    db.add(
        ClassroomEvent(
            class_id=class_id,
            user_id=user_id,
            event_type="group",
            payload={"group_size": group_size, "group_count": group_count, "groups": [[m["id"] for m in g] for g in groups]},
        )
    )
    await db.commit()
    return {"groups": groups, "total": len(items)}
