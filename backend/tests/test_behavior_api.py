"""Tests for the behavior tracking API — categories, records, and leaderboard."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.behavior import router as behavior_router
from app.api.class_ import router as class_router
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
    for r in (auth_router, class_router, students_router, behavior_router):
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


async def _setup(client, h):
    """Create class + 3 students. Returns (class_id, [s1, s2, s3])."""
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "行为班", "grade": "三"})
    cid = cls.json()["id"]
    sids = []
    for name, gender in [("甲", "male"), ("乙", "female"), ("丙", "male")]:
        s = await client.post("/api/v1/students", headers=h,
                              json={"class_id": cid, "name": name, "gender": gender})
        sids.append(s.json()["id"])
    return cid, sids


# ─── Categories ──────────────────────────────────────────────────────────────

async def test_list_categories_seeds_presets(client, monkeypatch):
    h = await _login(client, "13700010001", monkeypatch)
    cid, _ = await _setup(client, h)

    resp = await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)
    assert resp.status_code == 200
    cats = resp.json()
    assert len(cats) == 8
    assert all(c["is_preset"] for c in cats)
    names = {c["name"] for c in cats}
    assert "回答问题" in names
    assert "迟到" in names


async def test_create_custom_category(client, monkeypatch):
    h = await _login(client, "13700010002", monkeypatch)
    cid, _ = await _setup(client, h)

    resp = await client.post(
        f"/api/v1/behavior/categories/class/{cid}", headers=h,
        json={"name": "值日优秀", "icon": "cleaning_services", "score": 2, "sort_order": 10},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "值日优秀"
    assert resp.json()["is_preset"] is False

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    assert len(cats) == 9  # 8 preset + 1 custom


async def test_update_category(client, monkeypatch):
    h = await _login(client, "13700010003", monkeypatch)
    cid, _ = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    cat_id = cats[0]["id"]

    resp = await client.put(
        f"/api/v1/behavior/categories/{cat_id}", headers=h,
        json={"score": 5},
    )
    assert resp.status_code == 200
    assert resp.json()["score"] == 5


async def test_delete_category(client, monkeypatch):
    h = await _login(client, "13700010004", monkeypatch)
    cid, _ = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    cat_id = cats[-1]["id"]

    resp = await client.delete(f"/api/v1/behavior/categories/{cat_id}", headers=h)
    assert resp.status_code == 200

    cats2 = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    assert len(cats2) == 7


# ─── Records ─────────────────────────────────────────────────────────────────

async def test_create_single_record(client, monkeypatch):
    h = await _login(client, "13700010005", monkeypatch)
    cid, sids = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    good_cat = next(c for c in cats if c["score"] > 0)

    resp = await client.post(
        f"/api/v1/behavior/records/class/{cid}", headers=h,
        json={"student_ids": [sids[0]], "category_id": good_cat["id"], "note": "积极举手"},
    )
    assert resp.status_code == 200
    records = resp.json()
    assert len(records) == 1
    assert records[0]["score"] == good_cat["score"]
    assert records[0]["note"] == "积极举手"
    assert records[0]["student_name"] == "甲"


async def test_create_batch_records(client, monkeypatch):
    h = await _login(client, "13700010006", monkeypatch)
    cid, sids = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    cat = cats[0]

    resp = await client.post(
        f"/api/v1/behavior/records/class/{cid}", headers=h,
        json={"student_ids": sids, "category_id": cat["id"]},
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 3


async def test_create_record_wrong_student_rejected(client, monkeypatch):
    h = await _login(client, "13700010007", monkeypatch)
    cid, sids = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()

    resp = await client.post(
        f"/api/v1/behavior/records/class/{cid}", headers=h,
        json={"student_ids": [99999], "category_id": cats[0]["id"]},
    )
    assert resp.status_code == 400


async def test_list_class_records(client, monkeypatch):
    h = await _login(client, "13700010008", monkeypatch)
    cid, sids = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()

    # Create records
    await client.post(
        f"/api/v1/behavior/records/class/{cid}", headers=h,
        json={"student_ids": [sids[0]], "category_id": cats[0]["id"]},
    )
    await client.post(
        f"/api/v1/behavior/records/class/{cid}", headers=h,
        json={"student_ids": [sids[1]], "category_id": cats[4]["id"]},
    )

    # List all
    resp = await client.get(f"/api/v1/behavior/records/class/{cid}", headers=h)
    assert resp.status_code == 200
    assert len(resp.json()) == 2

    # Filter by student
    resp = await client.get(
        f"/api/v1/behavior/records/class/{cid}?student_id={sids[0]}", headers=h
    )
    assert len(resp.json()) == 1


async def test_delete_record(client, monkeypatch):
    h = await _login(client, "13700010009", monkeypatch)
    cid, sids = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    recs = (await client.post(
        f"/api/v1/behavior/records/class/{cid}", headers=h,
        json={"student_ids": [sids[0]], "category_id": cats[0]["id"]},
    )).json()

    resp = await client.delete(f"/api/v1/behavior/records/{recs[0]['id']}", headers=h)
    assert resp.status_code == 200

    listed = (await client.get(f"/api/v1/behavior/records/class/{cid}", headers=h)).json()
    assert len(listed) == 0


# ─── Leaderboard ─────────────────────────────────────────────────────────────

async def test_leaderboard(client, monkeypatch):
    h = await _login(client, "13700010010", monkeypatch)
    cid, sids = await _setup(client, h)

    cats = (await client.get(f"/api/v1/behavior/categories/class/{cid}", headers=h)).json()
    good = next(c for c in cats if c["name"] == "作业优秀")  # score=3
    bad = next(c for c in cats if c["name"] == "迟到")  # score=-1

    # 甲: +3, +3 = 6; 乙: -1; 丙: no records = 0
    await client.post(f"/api/v1/behavior/records/class/{cid}", headers=h,
                      json={"student_ids": [sids[0]], "category_id": good["id"]})
    await client.post(f"/api/v1/behavior/records/class/{cid}", headers=h,
                      json={"student_ids": [sids[0]], "category_id": good["id"]})
    await client.post(f"/api/v1/behavior/records/class/{cid}", headers=h,
                      json={"student_ids": [sids[1]], "category_id": bad["id"]})

    resp = await client.get(f"/api/v1/behavior/stats/class/{cid}", headers=h)
    assert resp.status_code == 200
    board = resp.json()
    assert len(board) == 3
    # Sorted desc by total_score
    assert board[0]["student_name"] == "甲"
    assert board[0]["total_score"] == 6
    assert board[0]["record_count"] == 2
    assert board[1]["student_name"] == "丙"
    assert board[1]["total_score"] == 0
    assert board[2]["student_name"] == "乙"
    assert board[2]["total_score"] == -1
