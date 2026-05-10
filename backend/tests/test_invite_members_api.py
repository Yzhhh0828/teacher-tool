"""Tests for invitation enhancements — member list, update, remove, revoke code."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
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
    for r in (auth_router, class_router):
        app.include_router(r, prefix="/api/v1")

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    verification_store._entries.clear()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
        yield c


async def _login(c, phone, monkeypatch) -> dict:
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)
    r = await c.post("/api/v1/auth/send_code", json={"phone": phone})
    code = r.json()["debug_code"]
    r = await c.post("/api/v1/auth/login", json={"phone": phone, "code": code})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


async def test_list_members(client, monkeypatch):
    h1 = await _login(client, "13600010001", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "成员班", "grade": "四"})
    cid = cls.json()["id"]

    resp = await client.get(f"/api/v1/classes/{cid}/members", headers=h1)
    assert resp.status_code == 200
    members = resp.json()
    assert len(members) == 1
    assert members[0]["role"] == "owner"


async def test_join_and_list_members(client, monkeypatch):
    h1 = await _login(client, "13600010002", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "协作班", "grade": "五"})
    cid = cls.json()["id"]

    # Generate invite code
    inv = await client.post(f"/api/v1/classes/{cid}/invite_code", headers=h1)
    code = inv.json()["invite_code"]

    # Second user joins
    h2 = await _login(client, "13600010003", monkeypatch)
    join_resp = await client.post("/api/v1/classes/join", headers=h2,
                                  json={"invite_code": code, "subject": "数学"})
    assert join_resp.status_code == 200

    # Both should be listed
    resp = await client.get(f"/api/v1/classes/{cid}/members", headers=h1)
    assert len(resp.json()) == 2


async def test_update_member_subject(client, monkeypatch):
    h1 = await _login(client, "13600010004", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "改科班", "grade": "六"})
    cid = cls.json()["id"]

    inv = await client.post(f"/api/v1/classes/{cid}/invite_code", headers=h1)
    code = inv.json()["invite_code"]

    h2 = await _login(client, "13600010005", monkeypatch)
    await client.post("/api/v1/classes/join", headers=h2,
                      json={"invite_code": code, "subject": "英语"})

    members = (await client.get(f"/api/v1/classes/{cid}/members", headers=h1)).json()
    teacher = next(m for m in members if m["role"] == "teacher")

    resp = await client.put(
        f"/api/v1/classes/{cid}/members/{teacher['id']}", headers=h1,
        json={"subject": "语文"},
    )
    assert resp.status_code == 200


async def test_remove_member(client, monkeypatch):
    h1 = await _login(client, "13600010006", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "踢人班", "grade": "一"})
    cid = cls.json()["id"]

    inv = await client.post(f"/api/v1/classes/{cid}/invite_code", headers=h1)
    code = inv.json()["invite_code"]

    h2 = await _login(client, "13600010007", monkeypatch)
    await client.post("/api/v1/classes/join", headers=h2,
                      json={"invite_code": code, "subject": "体育"})

    members = (await client.get(f"/api/v1/classes/{cid}/members", headers=h1)).json()
    teacher = next(m for m in members if m["role"] == "teacher")

    resp = await client.delete(f"/api/v1/classes/{cid}/members/{teacher['id']}", headers=h1)
    assert resp.status_code == 200

    members2 = (await client.get(f"/api/v1/classes/{cid}/members", headers=h1)).json()
    assert len(members2) == 1


async def test_cannot_remove_owner(client, monkeypatch):
    h1 = await _login(client, "13600010008", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "护主班", "grade": "二"})
    cid = cls.json()["id"]

    members = (await client.get(f"/api/v1/classes/{cid}/members", headers=h1)).json()
    owner = next(m for m in members if m["role"] == "owner")

    resp = await client.delete(f"/api/v1/classes/{cid}/members/{owner['id']}", headers=h1)
    assert resp.status_code == 400


async def test_revoke_invite_code(client, monkeypatch):
    h1 = await _login(client, "13600010009", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "作废班", "grade": "三"})
    cid = cls.json()["id"]

    # Generate then revoke
    inv = await client.post(f"/api/v1/classes/{cid}/invite_code", headers=h1)
    code = inv.json()["invite_code"]

    resp = await client.delete(f"/api/v1/classes/{cid}/invite_code", headers=h1)
    assert resp.status_code == 200

    # Trying to join with revoked code should fail
    h2 = await _login(client, "13600010010", monkeypatch)
    join_resp = await client.post("/api/v1/classes/join", headers=h2,
                                  json={"invite_code": code, "subject": "美术"})
    assert join_resp.status_code == 404


async def test_non_owner_cannot_remove_member(client, monkeypatch):
    h1 = await _login(client, "13600010011", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h1, json={"name": "权限班", "grade": "四"})
    cid = cls.json()["id"]

    inv = await client.post(f"/api/v1/classes/{cid}/invite_code", headers=h1)
    code = inv.json()["invite_code"]

    h2 = await _login(client, "13600010012", monkeypatch)
    await client.post("/api/v1/classes/join", headers=h2,
                      json={"invite_code": code, "subject": "音乐"})

    members = (await client.get(f"/api/v1/classes/{cid}/members", headers=h1)).json()
    owner = next(m for m in members if m["role"] == "owner")

    # Teacher trying to remove owner should fail with 403
    resp = await client.delete(f"/api/v1/classes/{cid}/members/{owner['id']}", headers=h2)
    assert resp.status_code == 403
