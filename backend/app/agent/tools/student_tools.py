"""Student CRUD + bulk-create tools."""
from __future__ import annotations

from typing import Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.tools.registry import registry
from app.agent.audit import log_action
from app.mcp.tools import MCPTools


@registry.tool(
    name="list_students",
    description="列出某个班级下的全部学生（只读）。",
    parameters={
        "type": "object",
        "properties": {"class_id": {"type": "integer", "description": "班级 ID"}},
        "required": ["class_id"],
    },
    category="student",
)
async def list_students(*, db: AsyncSession, user_id: int, class_id: int) -> dict[str, Any]:
    items = await MCPTools(db, user_id).get_students(class_id)
    return {"class_id": class_id, "count": len(items), "items": items}


@registry.tool(
    name="add_student",
    description="为指定班级添加单个学生。需要用户确认。",
    parameters={
        "type": "object",
        "properties": {
            "class_id": {"type": "integer"},
            "name": {"type": "string"},
            "gender": {"type": "string", "enum": ["male", "female", "other"]},
            "phone": {"type": "string"},
            "parent_phone": {"type": "string"},
            "student_no": {"type": "string", "description": "学号"},
            "birthday": {"type": "string", "description": "生日 YYYY-MM-DD"},
            "parent_name": {"type": "string", "description": "家长姓名"},
            "address": {"type": "string", "description": "家庭住址"},
            "home_phone": {"type": "string", "description": "家庭电话"},
            "hobbies": {"type": "string", "description": "兴趣爱好"},
            "health": {"type": "string", "description": "健康状况"},
            "emergency_contact": {"type": "string", "description": "紧急联系人"},
            "description": {"type": "string", "description": "学生描述"},
        },
        "required": ["class_id", "name", "gender"],
    },
    requires_confirmation=True,
    category="student",
)
async def add_student(
    *,
    db: AsyncSession,
    user_id: int,
    class_id: int,
    name: str,
    gender: str,
    phone: Optional[str] = None,
    parent_phone: Optional[str] = None,
    student_no: Optional[str] = None,
    birthday: Optional[str] = None,
    parent_name: Optional[str] = None,
    address: Optional[str] = None,
    home_phone: Optional[str] = None,
    hobbies: Optional[str] = None,
    health: Optional[str] = None,
    emergency_contact: Optional[str] = None,
    description: Optional[str] = None,
) -> dict[str, Any]:
    result = await MCPTools(db, user_id).add_student(
        class_id, name, gender, phone, parent_phone,
        student_no=student_no, birthday=birthday,
        parent_name=parent_name, address=address,
        home_phone=home_phone, hobbies=hobbies,
        health=health, emergency_contact=emergency_contact,
        description=description,
    )
    await log_action(
        db,
        user_id=user_id,
        action_type="add_student",
        payload={"class_id": class_id, "name": name, "gender": gender},
        diff={"created": 1, "names": [name]},
        undo_payload={"created_student_ids": [result["id"]]} if isinstance(result, dict) and result.get("id") else {},
    )
    return result


@registry.tool(
    name="bulk_create_students",
    description="批量在班级下创建学生（按姓名去重，已存在的跳过）。返回 diff（新增/跳过 行数）。需要用户确认。",
    parameters={
        "type": "object",
        "properties": {
            "class_id": {"type": "integer"},
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "gender": {"type": "string"},
                        "phone": {"type": "string"},
                        "parent_phone": {"type": "string"},
                    },
                    "required": ["name", "gender"],
                },
            },
        },
        "required": ["class_id", "items"],
    },
    requires_confirmation=True,
    category="student",
)
async def bulk_create_students(
    *,
    db: AsyncSession,
    user_id: int,
    class_id: int,
    items: list[dict[str, Any]],
) -> dict[str, Any]:
    from sqlalchemy import select
    from app.models.student import Student

    mcp = MCPTools(db, user_id)
    member = await mcp.check_class_permission(class_id)
    if member.role != "owner":
        raise PermissionError("Only owner can bulk-create students")

    existing = await db.execute(select(Student.name).where(Student.class_id == class_id))
    existing_names = {n for (n,) in existing.all()}

    created_rows: list[Student] = []
    skipped: list[str] = []
    for item in items:
        name = (item.get("name") or "").strip()
        if not name:
            continue
        if name in existing_names:
            skipped.append(name)
            continue
        student = Student(
            class_id=class_id,
            name=name,
            gender=item.get("gender", "other"),
            phone=item.get("phone"),
            parent_phone=item.get("parent_phone"),
        )
        db.add(student)
        existing_names.add(name)
        created_rows.append(student)
    await db.commit()
    for row in created_rows:
        await db.refresh(row)
    diff = {
        "created": len(created_rows),
        "skipped": len(skipped),
        "skipped_names": skipped,
        "names": [r.name for r in created_rows],
    }
    await log_action(
        db,
        user_id=user_id,
        action_type="bulk_create_students",
        payload={"class_id": class_id, "count": len(items)},
        diff=diff,
        undo_payload={"created_student_ids": [r.id for r in created_rows]},
    )
    return {"created": len(created_rows), "skipped": len(skipped), "skipped_names": skipped}


@registry.tool(
    name="update_student",
    description="更新指定学生的信息字段。需要用户确认。",
    parameters={
        "type": "object",
        "properties": {
            "student_id": {"type": "integer"},
            "name": {"type": "string"},
            "gender": {"type": "string"},
            "phone": {"type": "string"},
            "parent_phone": {"type": "string"},
            "remarks": {"type": "string"},
            "student_no": {"type": "string"},
            "birthday": {"type": "string"},
            "parent_name": {"type": "string"},
            "address": {"type": "string"},
            "home_phone": {"type": "string"},
            "hobbies": {"type": "string"},
            "health": {"type": "string"},
            "emergency_contact": {"type": "string"},
            "description": {"type": "string"},
        },
        "required": ["student_id"],
    },
    requires_confirmation=True,
    category="student",
)
async def update_student(*, db: AsyncSession, user_id: int, student_id: int, **fields: Any) -> dict[str, Any]:
    return await MCPTools(db, user_id).update_student(student_id, **fields)


@registry.tool(
    name="delete_student",
    description="删除指定学生。需要用户确认。",
    parameters={
        "type": "object",
        "properties": {"student_id": {"type": "integer"}},
        "required": ["student_id"],
    },
    requires_confirmation=True,
    category="student",
)
async def delete_student(*, db: AsyncSession, user_id: int, student_id: int) -> dict[str, Any]:
    return await MCPTools(db, user_id).delete_student(student_id)
