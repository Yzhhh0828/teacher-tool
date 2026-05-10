"""Tests for the audit/undo subsystem and the /agent/actions endpoints."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.agent import router as agent_router
from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.students import router as students_router
from app.api.grades import router as grades_router
from app.config import settings
from app.database import Base, get_db
from app.models.agent_action import AgentAction
from app.models.student import Student


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
    app.include_router(auth_router, prefix="/api/v1")
    app.include_router(class_router, prefix="/api/v1")
    app.include_router(students_router, prefix="/api/v1")
    app.include_router(grades_router, prefix="/api/v1")
    app.include_router(agent_router, prefix="/api/v1")

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


async def test_bulk_create_then_undo(client, monkeypatch, db_session):
    h = await _login(client, "13900100001", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "C", "grade": "G"})
    class_id = cls.json()["id"]

    # Invoke the bulk-create tool (write -> requires confirmation).
    pending = await client.post(
        "/api/v1/agent/tools/invoke",
        headers=h,
        json={
            "name": "bulk_create_students",
            "arguments": {
                "class_id": class_id,
                "items": [
                    {"name": "甲", "gender": "male"},
                    {"name": "乙", "gender": "female"},
                ],
            },
            "confirmed": False,
        },
    )
    assert pending.status_code == 200
    assert pending.json()["status"] == "pending_confirmation"

    confirmed = await client.post(
        "/api/v1/agent/tools/invoke",
        headers=h,
        json={
            "name": "bulk_create_students",
            "arguments": {
                "class_id": class_id,
                "items": [
                    {"name": "甲", "gender": "male"},
                    {"name": "乙", "gender": "female"},
                ],
            },
            "confirmed": True,
        },
    )
    assert confirmed.status_code == 200
    assert confirmed.json()["result"]["created"] == 2

    # Audit row must exist.
    actions = (await client.get("/api/v1/agent/actions", headers=h)).json()
    assert any(a["action_type"] == "bulk_create_students" for a in actions["items"])
    action_id = actions["items"][0]["id"]

    # Students should be present.
    stmt = select(Student).where(Student.class_id == class_id)
    rows_before = (await db_session.execute(stmt)).scalars().all()
    assert {s.name for s in rows_before} == {"甲", "乙"}

    # Undo and verify removal.
    undo = await client.post(f"/api/v1/agent/actions/{action_id}/undo", headers=h)
    assert undo.status_code == 200
    assert undo.json()["new_status"] == "undone"

    rows_after = (await db_session.execute(stmt)).scalars().all()
    assert rows_after == []

    # Re-undoing the same action is rejected.
    again = await client.post(f"/api/v1/agent/actions/{action_id}/undo", headers=h)
    assert again.status_code == 400


async def test_undo_other_user_forbidden(client, monkeypatch, db_session):
    owner = await _login(client, "13900100002", monkeypatch)
    other = await _login(client, "13900100003", monkeypatch)

    cls = await client.post("/api/v1/classes", headers=owner, json={"name": "C", "grade": "G"})
    class_id = cls.json()["id"]

    await client.post(
        "/api/v1/agent/tools/invoke",
        headers=owner,
        json={
            "name": "bulk_create_students",
            "arguments": {"class_id": class_id, "items": [{"name": "X", "gender": "male"}]},
            "confirmed": True,
        },
    )
    aid = (
        await db_session.execute(select(AgentAction.id).order_by(AgentAction.id.desc()))
    ).scalar()

    forbidden = await client.post(f"/api/v1/agent/actions/{aid}/undo", headers=other)
    assert forbidden.status_code == 403
