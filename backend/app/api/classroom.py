"""Classroom front-stage endpoints: random pick, random groups, event log."""
from __future__ import annotations

import random
from datetime import datetime, UTC, timedelta
from typing import Any, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import check_class_permission, get_current_user
from app.database import get_db
from app.models.classroom import ClassroomEvent
from app.models.student import Student
from app.models.user import User


router = APIRouter(prefix="/classroom", tags=["classroom"])


class PickRequest(BaseModel):
    avoid_recent_minutes: int = Field(60, ge=0, le=24 * 60)
    exclude_ids: list[int] = Field(default_factory=list)


class GroupRequest(BaseModel):
    group_size: Optional[int] = Field(None, ge=1)
    group_count: Optional[int] = Field(None, ge=1)
    seed: Optional[int] = None


@router.post("/{class_id}/pick")
async def pick_random_student(
    class_id: int,
    body: PickRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    await check_class_permission(db, class_id, current_user)

    students = (
        await db.execute(select(Student).where(Student.class_id == class_id))
    ).scalars().all()
    if not students:
        return {"picked": None, "reason": "no_students"}

    cutoff = datetime.now(UTC) - timedelta(minutes=body.avoid_recent_minutes)
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
    exclude = recent_ids | set(body.exclude_ids)
    pool = [s for s in students if s.id not in exclude] or list(students)
    chosen = random.choice(pool)

    db.add(
        ClassroomEvent(
            class_id=class_id,
            user_id=current_user.id,
            event_type="pick",
            payload={"student_id": chosen.id, "student_name": chosen.name},
        )
    )
    await db.flush()
    return {
        "picked": {"id": chosen.id, "name": chosen.name, "gender": chosen.gender},
        "pool_size": len(pool),
    }


@router.post("/{class_id}/groups")
async def random_groups(
    class_id: int,
    body: GroupRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    await check_class_permission(db, class_id, current_user)
    students = (
        await db.execute(select(Student).where(Student.class_id == class_id))
    ).scalars().all()
    items = [{"id": s.id, "name": s.name} for s in students]
    rng = random.Random(body.seed) if body.seed is not None else random
    rng.shuffle(items)

    if body.group_count and body.group_count > 0:
        groups: list[list[dict[str, Any]]] = [[] for _ in range(body.group_count)]
        for i, it in enumerate(items):
            groups[i % body.group_count].append(it)
    else:
        size = max(1, body.group_size or 4)
        groups = [items[i : i + size] for i in range(0, len(items), size)]

    db.add(
        ClassroomEvent(
            class_id=class_id,
            user_id=current_user.id,
            event_type="group",
            payload={
                "group_size": body.group_size,
                "group_count": body.group_count,
                "groups": [[m["id"] for m in g] for g in groups],
            },
        )
    )
    await db.flush()
    return {"groups": groups, "total": len(items)}


@router.get("/{class_id}/events")
async def list_events(
    class_id: int,
    event_type: Optional[str] = None,
    limit: int = Query(50, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    await check_class_permission(db, class_id, current_user)
    q = select(ClassroomEvent).where(ClassroomEvent.class_id == class_id)
    if event_type:
        q = q.where(ClassroomEvent.event_type == event_type)
    q = q.order_by(ClassroomEvent.created_at.desc()).limit(limit)
    events = (await db.execute(q)).scalars().all()
    return {
        "items": [
            {
                "id": e.id,
                "event_type": e.event_type,
                "payload": e.payload,
                "created_at": e.created_at.isoformat(),
            }
            for e in events
        ]
    }
