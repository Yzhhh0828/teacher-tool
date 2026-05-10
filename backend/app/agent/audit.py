"""Audit logging + undo support for agent-driven write actions.

Every write tool calls :func:`log_action` after a successful commit. The row
captures:

* `action_type` — the tool name (e.g. ``bulk_create_students``)
* `payload`    — the (sanitised) arguments the tool was invoked with
* `diff`       — high-level summary returned to the user (counts, names)
* `undo_payload` — everything required to reverse the action

The :func:`undo_action` helper inspects ``action_type`` and applies the
inverse mutation, then marks the row as ``status='undone'``.
"""
from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent_action import AgentAction
from app.models.exam import Grade
from app.models.seating import Seating
from app.models.student import Student


async def log_action(
    db: AsyncSession,
    *,
    user_id: int,
    action_type: str,
    payload: dict[str, Any],
    diff: dict[str, Any],
    undo_payload: dict[str, Any],
    status: str = "committed",
) -> AgentAction:
    row = AgentAction(
        user_id=user_id,
        action_type=action_type,
        payload=payload,
        diff=diff,
        undo_payload=undo_payload,
        status=status,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


class UndoNotSupported(Exception):
    """Raised when an action cannot be reversed."""


async def undo_action(db: AsyncSession, *, user_id: int, action_id: int) -> AgentAction:
    """Reverse a previously committed action.

    Currently supports:

    * ``bulk_create_students``  → delete the students that were created
    * ``add_student``           → delete the created student
    * ``add_grade``             → delete the created grade row
    * ``bulk_upsert_grades``    → restore previous scores / delete created
    * ``apply_seating_layout``  → restore previous seats matrix
    """
    row = await db.get(AgentAction, action_id)
    if row is None:
        raise ValueError(f"Action {action_id} not found")
    if row.user_id != user_id:
        raise PermissionError("Not authorized to undo this action")
    if row.status != "committed":
        # Use UndoNotSupported so the API maps it to 400 instead of 404.
        raise UndoNotSupported(f"Action is {row.status}, cannot undo")

    payload = row.undo_payload or {}
    action_type = row.action_type

    if action_type in ("bulk_create_students", "add_student"):
        ids = payload.get("created_student_ids") or []
        if ids:
            stmt = select(Student).where(Student.id.in_(ids))
            for s in (await db.execute(stmt)).scalars():
                await db.delete(s)

    elif action_type == "add_grade":
        gid = payload.get("created_grade_id")
        if gid:
            g = await db.get(Grade, gid)
            if g is not None:
                await db.delete(g)

    elif action_type == "bulk_upsert_grades":
        # Delete grades created during the bulk action.
        for gid in payload.get("created_grade_ids", []):
            g = await db.get(Grade, gid)
            if g is not None:
                await db.delete(g)
        # Restore previous scores for grades that were updated.
        for prev in payload.get("updated_grade_snapshots", []):
            g = await db.get(Grade, prev["id"])
            if g is not None:
                g.score = prev["score"]

    elif action_type == "apply_seating_layout":
        prev = payload.get("previous_seats")
        class_id = payload.get("class_id")
        if prev is not None and class_id is not None:
            seating = (
                await db.execute(select(Seating).where(Seating.class_id == class_id))
            ).scalar_one_or_none()
            if seating is not None:
                seating.seats = prev

    else:
        raise UndoNotSupported(f"Undo not supported for {action_type}")

    row.status = "undone"
    await db.commit()
    await db.refresh(row)
    return row
