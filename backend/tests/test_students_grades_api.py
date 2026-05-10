"""Focused tests for students and grades CRUD API endpoints."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.grades import router as grades_router
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
    for r in (auth_router, class_router, students_router, grades_router):
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


# ─── Students ────────────────────────────────────────────────────────────────

async def test_create_student_with_all_fields(client, monkeypatch):
    h = await _login(client, "13800100001", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测A", "grade": "一"})
    cid = cls.json()["id"]

    resp = await client.post("/api/v1/students", headers=h, json={
        "class_id": cid, "name": "张三", "gender": "male",
        "phone": "13800000001", "parent_phone": "13900000001",
        "remarks": "班长",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "张三"
    assert data["phone"] == "13800000001"


async def test_update_student(client, monkeypatch):
    h = await _login(client, "13800100002", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测B", "grade": "二"})
    cid = cls.json()["id"]
    s = await client.post("/api/v1/students", headers=h,
                          json={"class_id": cid, "name": "旧名", "gender": "female"})
    sid = s.json()["id"]

    resp = await client.put(f"/api/v1/students/{sid}", headers=h,
                            json={"name": "新名", "gender": "male"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "新名"
    assert resp.json()["gender"] == "male"


async def test_delete_student_and_list_empty(client, monkeypatch):
    h = await _login(client, "13800100003", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测C", "grade": "三"})
    cid = cls.json()["id"]
    s = await client.post("/api/v1/students", headers=h,
                          json={"class_id": cid, "name": "删我", "gender": "male"})
    sid = s.json()["id"]

    resp = await client.delete(f"/api/v1/students/{sid}", headers=h)
    assert resp.status_code == 200

    listed = await client.get(f"/api/v1/students/class/{cid}", headers=h)
    assert listed.json() == []


# ─── Grades ──────────────────────────────────────────────────────────────────

async def test_create_grade_and_list(client, monkeypatch):
    h = await _login(client, "13800100004", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测D", "grade": "四"})
    cid = cls.json()["id"]
    s = await client.post("/api/v1/students", headers=h,
                          json={"class_id": cid, "name": "甲", "gender": "male"})
    sid = s.json()["id"]

    exam = await client.post("/api/v1/grades/exams", headers=h,
                             json={"class_id": cid, "name": "月考", "date": "2026-05-01T08:00:00"})
    eid = exam.json()["id"]

    # Create grade
    g = await client.post("/api/v1/grades", headers=h,
                          json={"exam_id": eid, "student_id": sid, "subject": "语文", "score": 88})
    assert g.status_code == 200
    assert g.json()["score"] == 88

    # List grades for exam
    listed = await client.get(f"/api/v1/grades/exams/{eid}", headers=h)
    assert listed.status_code == 200
    assert len(listed.json()) == 1


async def test_update_grade(client, monkeypatch):
    h = await _login(client, "13800100005", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测E", "grade": "五"})
    cid = cls.json()["id"]
    s = await client.post("/api/v1/students", headers=h,
                          json={"class_id": cid, "name": "乙", "gender": "female"})
    sid = s.json()["id"]
    exam = await client.post("/api/v1/grades/exams", headers=h,
                             json={"class_id": cid, "name": "期中", "date": "2026-04-10T08:00:00"})
    eid = exam.json()["id"]
    g = await client.post("/api/v1/grades", headers=h,
                          json={"exam_id": eid, "student_id": sid, "subject": "数学", "score": 60})
    gid = g.json()["id"]

    resp = await client.put(f"/api/v1/grades/{gid}", headers=h,
                            json={"score": 95})
    assert resp.status_code == 200
    assert resp.json()["score"] == 95


async def test_delete_grade(client, monkeypatch):
    h = await _login(client, "13800100006", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测F", "grade": "六"})
    cid = cls.json()["id"]
    s = await client.post("/api/v1/students", headers=h,
                          json={"class_id": cid, "name": "丙", "gender": "male"})
    sid = s.json()["id"]
    exam = await client.post("/api/v1/grades/exams", headers=h,
                             json={"class_id": cid, "name": "小测", "date": "2026-03-01T08:00:00"})
    eid = exam.json()["id"]
    g = await client.post("/api/v1/grades", headers=h,
                          json={"exam_id": eid, "student_id": sid, "subject": "英语", "score": 70})
    gid = g.json()["id"]

    resp = await client.delete(f"/api/v1/grades/{gid}", headers=h)
    assert resp.status_code == 200

    listed = await client.get(f"/api/v1/grades/exams/{eid}", headers=h)
    assert listed.json() == []


async def test_delete_exam_cascades(client, monkeypatch):
    h = await _login(client, "13800100007", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测G", "grade": "一"})
    cid = cls.json()["id"]
    s = await client.post("/api/v1/students", headers=h,
                          json={"class_id": cid, "name": "丁", "gender": "female"})
    sid = s.json()["id"]
    exam = await client.post("/api/v1/grades/exams", headers=h,
                             json={"class_id": cid, "name": "期末", "date": "2026-06-20T08:00:00"})
    eid = exam.json()["id"]
    await client.post("/api/v1/grades", headers=h,
                      json={"exam_id": eid, "student_id": sid, "subject": "数学", "score": 99})

    resp = await client.delete(f"/api/v1/grades/exams/{eid}", headers=h)
    assert resp.status_code == 200

    exams = await client.get(f"/api/v1/grades/exams/class/{cid}", headers=h)
    assert len(exams.json()) == 0
