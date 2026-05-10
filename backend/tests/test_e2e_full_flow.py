"""End-to-end happy path covering the new feature surface.

Walks a teacher account through:

1. Auth (send_code → login).
2. Create a class.
3. Bulk-import students via `/agent/tools/invoke` (with confirmation).
4. Create an exam and bulk-upsert grades via the agent tool path.
5. Read analytics overview + class compare.
6. Use classroom front-stage: pick + groups, then read events.
7. Verify the audit log lists both write actions.
8. Undo the bulk grade insert and confirm the grades vanish.
"""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.agent import router as agent_router
from app.api.analytics import router as analytics_router
from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.classroom import router as classroom_router
from app.api.grades import router as grades_router
from app.api.students import router as students_router
from app.config import settings
from app.database import Base, get_db
from app.models.exam import Grade


pytestmark = pytest.mark.asyncio


@pytest.fixture
async def db_session():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session
    await engine.dispose()


@pytest.fixture
async def client(db_session):
    app = FastAPI()
    for r in (
        auth_router,
        class_router,
        students_router,
        grades_router,
        analytics_router,
        classroom_router,
        agent_router,
    ):
        app.include_router(r, prefix="/api/v1")

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    verification_store._entries.clear()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
        yield c


async def _login(c: AsyncClient, phone: str, monkeypatch) -> dict:
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)
    r = await c.post("/api/v1/auth/send_code", json={"phone": phone})
    code = r.json()["debug_code"]
    r = await c.post("/api/v1/auth/login", json={"phone": phone, "code": code})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


async def _confirmed_invoke(c, headers, name, arguments):
    """Invoke a write tool with confirmation."""
    return await c.post(
        "/api/v1/agent/tools/invoke",
        headers=headers,
        json={"name": name, "arguments": arguments, "confirmed": True},
    )


async def test_full_teacher_flow(client, monkeypatch, db_session):
    h = await _login(client, "13900900001", monkeypatch)

    # 1. Create class.
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "三年二班", "grade": "三年级"})
    assert cls.status_code == 200
    class_id = cls.json()["id"]

    # 2. Bulk-import students.
    students_payload = [
        {"name": "张三", "gender": "male"},
        {"name": "李四", "gender": "female"},
        {"name": "王五", "gender": "male"},
        {"name": "赵六", "gender": "female"},
    ]
    bulk_students = await _confirmed_invoke(
        client, h, "bulk_create_students", {"class_id": class_id, "items": students_payload}
    )
    assert bulk_students.status_code == 200
    assert bulk_students.json()["result"]["created"] == 4

    listed = await client.get(f"/api/v1/students/class/{class_id}", headers=h)
    students = listed.json()
    assert len(students) == 4
    name_to_id = {s["name"]: s["id"] for s in students}

    # 3. Create an exam, then bulk-upsert grades.
    exam_create = await client.post(
        "/api/v1/grades/exams",
        headers=h,
        json={"class_id": class_id, "name": "期中考试", "date": "2026-04-15T08:00:00"},
    )
    exam_id = exam_create.json()["id"]

    grade_items = [
        {"student_id": name_to_id["张三"], "subject": "数学", "score": 92},
        {"student_id": name_to_id["李四"], "subject": "数学", "score": 78},
        {"student_id": name_to_id["王五"], "subject": "数学", "score": 85},
        {"student_id": name_to_id["赵六"], "subject": "数学", "score": 60},
    ]
    bulk_grades = await _confirmed_invoke(
        client, h, "bulk_upsert_grades", {"exam_id": exam_id, "items": grade_items}
    )
    assert bulk_grades.status_code == 200
    assert bulk_grades.json()["result"]["created"] == 4

    # 4. Analytics endpoints.
    overview = await client.get(f"/api/v1/analytics/class/{class_id}/overview", headers=h)
    assert overview.status_code == 200
    body = overview.json()
    assert body["student_count"] == 4
    assert body["exam_count"] == 1
    assert body["last_exam"]["id"] == exam_id

    distribution = await client.get(f"/api/v1/analytics/exam/{exam_id}/distribution", headers=h)
    assert distribution.status_code == 200
    subjects = distribution.json()["subjects"]
    assert "数学" in subjects
    assert subjects["数学"]["stats"]["mean"] is not None

    compare = await client.get(f"/api/v1/analytics/class/{class_id}/compare", headers=h)
    assert compare.status_code == 200
    assert len(compare.json()["series"]) == 1

    # 5. Classroom front-stage: pick + groups + events.
    pick = await client.post(f"/api/v1/classroom/{class_id}/pick", headers=h, json={})
    assert pick.status_code == 200
    assert pick.json()["picked"]["name"] in name_to_id

    groups = await client.post(
        f"/api/v1/classroom/{class_id}/groups",
        headers=h,
        json={"group_size": 2, "seed": 7},
    )
    assert groups.status_code == 200
    flat = [m for g in groups.json()["groups"] for m in g]
    assert len(flat) == 4

    events = await client.get(f"/api/v1/classroom/{class_id}/events", headers=h)
    types = {e["event_type"] for e in events.json()["items"]}
    assert {"pick", "group"}.issubset(types)

    # 6. Audit log + undo of the bulk grade write.
    actions = await client.get("/api/v1/agent/actions", headers=h)
    items = actions.json()["items"]
    types = [a["action_type"] for a in items]
    assert "bulk_create_students" in types
    assert "bulk_upsert_grades" in types

    grade_action_id = next(a["id"] for a in items if a["action_type"] == "bulk_upsert_grades")
    undo = await client.post(f"/api/v1/agent/actions/{grade_action_id}/undo", headers=h)
    assert undo.status_code == 200

    remaining = (
        await db_session.execute(select(Grade).where(Grade.exam_id == exam_id))
    ).scalars().all()
    assert remaining == []
