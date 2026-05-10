"""Integration tests for the new analytics + classroom endpoints."""
from __future__ import annotations

from datetime import datetime, UTC

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.students import router as students_router
from app.api.grades import router as grades_router
from app.api.analytics import router as analytics_router
from app.api.classroom import router as classroom_router
from app.config import settings
from app.database import Base, get_db


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
    app.include_router(analytics_router, prefix="/api/v1")
    app.include_router(classroom_router, prefix="/api/v1")

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


async def _seed_class_with_students(c: AsyncClient, headers: dict, names: list[str]) -> int:
    r = await c.post("/api/v1/classes", headers=headers, json={"name": "C", "grade": "G"})
    cid = r.json()["id"]
    for n in names:
        await c.post(
            "/api/v1/students",
            headers=headers,
            json={"class_id": cid, "name": n, "gender": "male"},
        )
    return cid


async def test_class_overview_no_exam(client, monkeypatch):
    h = await _login(client, "13900001001", monkeypatch)
    cid = await _seed_class_with_students(client, h, ["A", "B"])
    r = await client.get(f"/api/v1/analytics/class/{cid}/overview", headers=h)
    assert r.status_code == 200
    data = r.json()
    assert data["student_count"] == 2
    assert data["exam_count"] == 0
    assert data["last_exam"] is None


async def test_classroom_pick_records_event(client, monkeypatch):
    h = await _login(client, "13900001002", monkeypatch)
    cid = await _seed_class_with_students(client, h, ["A", "B", "C"])

    r = await client.post(f"/api/v1/classroom/{cid}/pick", headers=h, json={})
    assert r.status_code == 200
    body = r.json()
    assert body["picked"]["name"] in ("A", "B", "C")

    ev = await client.get(f"/api/v1/classroom/{cid}/events", headers=h, params={"event_type": "pick"})
    assert ev.status_code == 200
    assert len(ev.json()["items"]) == 1


async def test_classroom_groups_balanced(client, monkeypatch):
    h = await _login(client, "13900001003", monkeypatch)
    cid = await _seed_class_with_students(client, h, list("ABCDEFGH"))
    r = await client.post(
        f"/api/v1/classroom/{cid}/groups",
        headers=h,
        json={"group_count": 3, "seed": 42},
    )
    assert r.status_code == 200
    groups = r.json()["groups"]
    assert len(groups) == 3
    assert sum(len(g) for g in groups) == 8


async def test_classroom_pick_avoid_recent(client, monkeypatch):
    h = await _login(client, "13900001004", monkeypatch)
    cid = await _seed_class_with_students(client, h, ["A", "B"])
    seen = set()
    for _ in range(2):
        r = await client.post(f"/api/v1/classroom/{cid}/pick", headers=h, json={"avoid_recent_minutes": 60})
        seen.add(r.json()["picked"]["name"])
    assert seen == {"A", "B"}
