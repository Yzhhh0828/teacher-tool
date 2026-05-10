"""Seating-layout tools."""
from __future__ import annotations

from typing import Any, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.tools.registry import registry
from app.agent.audit import log_action
from app.mcp.tools import MCPTools
from app.models.seating import Seating
from app.models.student import Student


@registry.tool(
    name="get_seating",
    description="读取某班级当前的座位表布局（只读）。",
    parameters={
        "type": "object",
        "properties": {"class_id": {"type": "integer"}},
        "required": ["class_id"],
    },
    category="seating",
)
async def get_seating(*, db: AsyncSession, user_id: int, class_id: int) -> dict[str, Any]:
    return await MCPTools(db, user_id).get_seating(class_id)


@registry.tool(
    name="apply_seating_layout",
    description=(
        "将一个二维姓名/学号网格应用到班级座位表上。"
        "grid 元素可以是 学生 ID、学生姓名 或 null（空座）。需要用户确认。"
    ),
    parameters={
        "type": "object",
        "properties": {
            "class_id": {"type": "integer"},
            "grid": {
                "type": "array",
                "items": {"type": "array", "items": {"type": ["string", "integer", "null"]}},
            },
        },
        "required": ["class_id", "grid"],
    },
    requires_confirmation=True,
    category="seating",
)
async def apply_seating_layout(
    *, db: AsyncSession, user_id: int, class_id: int, grid: list[list[Any]]
) -> dict[str, Any]:
    mcp = MCPTools(db, user_id)
    member = await mcp.check_class_permission(class_id)
    if member.role != "owner":
        raise PermissionError("Only owner can apply seating")

    students = (
        await db.execute(select(Student).where(Student.class_id == class_id))
    ).scalars().all()
    by_name = {s.name: s.id for s in students}
    valid_ids = {s.id for s in students}

    rows = len(grid)
    cols = max((len(r) for r in grid), default=0)
    seats: list[list[Optional[int]]] = []
    unmatched: list[str] = []
    for r in grid:
        row: list[Optional[int]] = []
        for cell in (r + [None] * (cols - len(r))):
            if cell is None or cell == "":
                row.append(None)
            elif isinstance(cell, int) and cell in valid_ids:
                row.append(cell)
            elif isinstance(cell, str):
                sid = by_name.get(cell.strip())
                if sid is None:
                    unmatched.append(cell)
                row.append(sid)
            else:
                unmatched.append(str(cell))
                row.append(None)
        seats.append(row)

    seating = (
        await db.execute(select(Seating).where(Seating.class_id == class_id))
    ).scalar_one_or_none()
    previous_seats = seating.seats if seating else None
    if seating:
        seating.rows = rows
        seating.cols = cols
        seating.seats = seats
    else:
        db.add(Seating(class_id=class_id, rows=rows, cols=cols, seats=seats))
    await db.commit()
    await log_action(
        db,
        user_id=user_id,
        action_type="apply_seating_layout",
        payload={"class_id": class_id, "rows": rows, "cols": cols},
        diff={"unmatched": unmatched, "rows": rows, "cols": cols},
        undo_payload={"class_id": class_id, "previous_seats": previous_seats},
    )
    return {"rows": rows, "cols": cols, "unmatched": unmatched, "applied": True}


@registry.tool(
    name="random_shuffle_seats",
    description="随机打乱座位（按现有 rows×cols 网格）。需要用户确认。",
    parameters={
        "type": "object",
        "properties": {"class_id": {"type": "integer"}},
        "required": ["class_id"],
    },
    requires_confirmation=True,
    category="seating",
)
async def random_shuffle_seats(*, db: AsyncSession, user_id: int, class_id: int) -> dict[str, Any]:
    return await MCPTools(db, user_id).random_shuffle_seats(class_id)
