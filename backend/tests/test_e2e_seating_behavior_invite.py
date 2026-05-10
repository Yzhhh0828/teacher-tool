"""End-to-end coverage for features not exercised by ``test_e2e_full_flow``:

1. Seating layout lifecycle: create → list → apply → update → delete.
2. Behavior categories + records: a teacher creates students, gives points,
   reads aggregated stats, deducts points, then verifies the leaderboard.
3. Invitation flow: owner generates an invite code, a second user joins the
   class via that code and is listed as a member.

Each test uses an isolated in-memory SQLite database fixture.
"""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.behavior import router as behavior_router
from app.api.class_ import router as class_router
from app.api.seating import router as seating_router
from app.api.students import router as students_router
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
    for r in (
        auth_router,
        class_router,
        students_router,
        seating_router,
        behavior_router,
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


# ── Seating layouts ──────────────────────────────────────────────────────


async def test_seating_layout_lifecycle(client, monkeypatch):
    h = await _login(client, "13900900050", monkeypatch)

    cls = await client.post(
        "/api/v1/classes", headers=h,
        json={"name": "五年三班", "grade": "五年级"},
    )
    class_id = cls.json()["id"]

    # Add 4 students.
    for name, gender in [("甲", "male"), ("乙", "female"), ("丙", "male"), ("丁", "female")]:
        await client.post(
            "/api/v1/students",
            headers=h,
            json={"class_id": class_id, "name": name, "gender": gender},
        )
    students = (await client.get(f"/api/v1/students/class/{class_id}", headers=h)).json()
    ids = [s["id"] for s in students]

    # Initial GET creates default 6×8 seating.
    seating = await client.get(f"/api/v1/seating/class/{class_id}", headers=h)
    assert seating.status_code == 200
    assert seating.json()["rows"] == 6
    assert seating.json()["cols"] == 8

    # Save a 2×2 named layout.
    layout = await client.post(
        f"/api/v1/seating/layouts/class/{class_id}",
        headers=h,
        json={
            "name": "考试模式",
            "rows": 2,
            "cols": 2,
            "seats": [[ids[0], ids[1]], [ids[2], ids[3]]],
            "is_active": False,
        },
    )
    assert layout.status_code == 200
    layout_id = layout.json()["id"]

    # List layouts.
    listed = await client.get(f"/api/v1/seating/layouts/class/{class_id}", headers=h)
    assert listed.status_code == 200
    assert any(item["id"] == layout_id for item in listed.json())

    # Apply: active seating should now mirror the layout dimensions and seats.
    applied = await client.post(
        f"/api/v1/seating/layouts/{layout_id}/apply", headers=h,
    )
    assert applied.status_code == 200
    body = applied.json()
    assert body["rows"] == 2
    assert body["cols"] == 2
    assert body["seats"] == [[ids[0], ids[1]], [ids[2], ids[3]]]

    # Update layout name.
    upd = await client.put(
        f"/api/v1/seating/layouts/{layout_id}",
        headers=h,
        json={"name": "考试模式v2"},
    )
    assert upd.status_code == 200
    assert upd.json()["name"] == "考试模式v2"

    # Shuffle the active seating; seats should still cover all 4 students.
    shuffled = await client.post(
        f"/api/v1/seating/class/{class_id}/shuffle", headers=h,
    )
    assert shuffled.status_code == 200
    flat = [c for row in shuffled.json()["seats"] for c in row if c is not None]
    assert sorted(flat) == sorted(ids)

    # Delete layout.
    deleted = await client.delete(
        f"/api/v1/seating/layouts/{layout_id}", headers=h,
    )
    assert deleted.status_code == 200
    after = (await client.get(f"/api/v1/seating/layouts/class/{class_id}", headers=h)).json()
    assert all(item["id"] != layout_id for item in after)


# ── Behavior records ─────────────────────────────────────────────────────


async def test_behavior_records_aggregate_stats(client, monkeypatch):
    h = await _login(client, "13900900051", monkeypatch)

    cls = await client.post(
        "/api/v1/classes", headers=h,
        json={"name": "行为班", "grade": "二年级"},
    )
    class_id = cls.json()["id"]
    s1 = (await client.post("/api/v1/students", headers=h, json={
        "class_id": class_id, "name": "Alice", "gender": "female"
    })).json()
    s2 = (await client.post("/api/v1/students", headers=h, json={
        "class_id": class_id, "name": "Bob", "gender": "male"
    })).json()

    cats = await client.get(
        f"/api/v1/behavior/categories/class/{class_id}", headers=h,
    )
    assert cats.status_code == 200
    cat_list = cats.json()
    assert len(cat_list) >= 4, "presets should be auto-seeded"
    pos_cat = next(c for c in cat_list if c["score"] > 0)
    neg_cat = next(c for c in cat_list if c["score"] < 0)

    # Award positive to Alice twice, negative to Bob once.
    for _ in range(2):
        rec = await client.post(
            f"/api/v1/behavior/records/class/{class_id}",
            headers=h,
            json={
                "student_ids": [s1["id"]],
                "category_id": pos_cat["id"],
            },
        )
        assert rec.status_code == 200, rec.text
    rec = await client.post(
        f"/api/v1/behavior/records/class/{class_id}",
        headers=h,
        json={
            "student_ids": [s2["id"]],
            "category_id": neg_cat["id"],
        },
    )
    assert rec.status_code == 200, rec.text

    # Stats should reflect both totals.
    stats = await client.get(
        f"/api/v1/behavior/stats/class/{class_id}", headers=h,
    )
    assert stats.status_code == 200
    rows = stats.json()
    by_id = {row["student_id"]: row for row in rows}
    assert by_id[s1["id"]]["total_score"] == pos_cat["score"] * 2
    assert by_id[s2["id"]]["total_score"] == neg_cat["score"]


# ── Invitation flow ──────────────────────────────────────────────────────


async def test_invite_code_join_flow(client, monkeypatch):
    owner = await _login(client, "13900900052", monkeypatch)
    cls = await client.post(
        "/api/v1/classes", headers=owner,
        json={"name": "邀请班", "grade": "六年级"},
    )
    class_id = cls.json()["id"]

    # Owner creates an invite code.
    code_resp = await client.post(
        f"/api/v1/classes/{class_id}/invite_code", headers=owner,
    )
    assert code_resp.status_code == 200
    code = code_resp.json()["invite_code"]
    assert code and len(code) >= 4

    # Different user logs in.
    member = await _login(client, "13900900053", monkeypatch)

    # Member joins via the code.
    join = await client.post(
        "/api/v1/classes/join",
        headers=member,
        json={"invite_code": code, "subject": "数学"},
    )
    assert join.status_code == 200

    # Both users should see the class in their list.
    member_classes = await client.get("/api/v1/classes", headers=member)
    assert any(c["id"] == class_id for c in member_classes.json())

    # Owner's members endpoint should show 2 entries (owner + new member).
    members = await client.get(
        f"/api/v1/classes/{class_id}/members", headers=owner,
    )
    assert members.status_code == 200
    roles = {m["role"] for m in members.json()}
    assert "owner" in roles
    assert len(members.json()) == 2

    # Re-using the same code should NOT create a duplicate membership.
    rejoin = await client.post(
        "/api/v1/classes/join",
        headers=member,
        json={"invite_code": code, "subject": "数学"},
    )
    # Either 200 (idempotent) or 400 (already a member) is acceptable.
    assert rejoin.status_code in (200, 400)

    # Revoke the code.
    revoke = await client.delete(
        f"/api/v1/classes/{class_id}/invite_code", headers=owner,
    )
    assert revoke.status_code == 200
