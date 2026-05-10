"""Tests for dashboard and seating layout endpoints."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.dashboard import router as dashboard_router
from app.api.grades import router as grades_router
from app.api.seating import router as seating_router
from app.api.students import router as students_router
from app.api.schedules import router as schedules_router
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
    for r in (auth_router, class_router, students_router, grades_router,
              seating_router, schedules_router, dashboard_router):
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


async def test_dashboard_empty_class(client, monkeypatch):
    h = await _login(client, "13900001111", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "空班", "grade": "一"})
    class_id = cls.json()["id"]

    resp = await client.get(f"/api/v1/dashboard/class/{class_id}", headers=h)
    assert resp.status_code == 200
    data = resp.json()
    assert data["student_count"] == 0
    assert data["exam_count"] == 0
    assert data["latest_exam_name"] is None


async def test_dashboard_with_students_and_exam(client, monkeypatch):
    h = await _login(client, "13900002222", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "测试班", "grade": "三"})
    class_id = cls.json()["id"]

    # Add students
    s1 = await client.post("/api/v1/students", headers=h,
                           json={"class_id": class_id, "name": "甲", "gender": "male"})
    s2 = await client.post("/api/v1/students", headers=h,
                           json={"class_id": class_id, "name": "乙", "gender": "female"})

    # Create exam + grades
    exam = await client.post("/api/v1/grades/exams", headers=h,
                             json={"class_id": class_id, "name": "测验", "date": "2026-05-01T08:00:00"})
    exam_id = exam.json()["id"]

    await client.post("/api/v1/grades", headers=h,
                      json={"exam_id": exam_id, "student_id": s1.json()["id"], "subject": "数学", "score": 90})
    await client.post("/api/v1/grades", headers=h,
                      json={"exam_id": exam_id, "student_id": s2.json()["id"], "subject": "数学", "score": 80})

    resp = await client.get(f"/api/v1/dashboard/class/{class_id}", headers=h)
    assert resp.status_code == 200
    data = resp.json()
    assert data["student_count"] == 2
    assert data["male_count"] == 1
    assert data["female_count"] == 1
    assert data["exam_count"] == 1
    assert data["latest_exam_name"] == "测验"
    assert data["latest_exam_avg"] is not None
    assert data["grade_entry_count"] == 2


async def test_seating_layout_crud(client, monkeypatch):
    h = await _login(client, "13900003333", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "布局班", "grade": "二"})
    class_id = cls.json()["id"]

    # Create layout
    create_resp = await client.post(
        f"/api/v1/seating/layouts/class/{class_id}", headers=h,
        json={"name": "默认", "rows": 4, "cols": 6, "seats": [], "is_active": True})
    assert create_resp.status_code == 200
    layout_id = create_resp.json()["id"]

    # List layouts
    list_resp = await client.get(f"/api/v1/seating/layouts/class/{class_id}", headers=h)
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1

    # Update layout
    update_resp = await client.put(
        f"/api/v1/seating/layouts/{layout_id}", headers=h,
        json={"name": "更新后的布局", "rows": 5, "cols": 7})
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "更新后的布局"
    assert update_resp.json()["rows"] == 5

    # Apply layout
    apply_resp = await client.post(
        f"/api/v1/seating/layouts/{layout_id}/apply", headers=h)
    assert apply_resp.status_code == 200

    # Delete layout
    del_resp = await client.delete(f"/api/v1/seating/layouts/{layout_id}", headers=h)
    assert del_resp.status_code == 200
    assert del_resp.json()["message"] == "Layout deleted"

    # Verify list is now empty
    list_resp2 = await client.get(f"/api/v1/seating/layouts/class/{class_id}", headers=h)
    assert len(list_resp2.json()) == 0


async def test_seating_get_creates_default_and_shuffle(client, monkeypatch):
    h = await _login(client, "13900004444", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "座位班", "grade": "一"})
    class_id = cls.json()["id"]

    # Add students first
    for name in ["A同学", "B同学", "C同学"]:
        await client.post("/api/v1/students", headers=h,
                          json={"class_id": class_id, "name": name, "gender": "male"})

    # GET seating auto-creates default
    get_resp = await client.get(f"/api/v1/seating/class/{class_id}", headers=h)
    assert get_resp.status_code == 200
    assert get_resp.json()["rows"] == 6
    assert get_resp.json()["cols"] == 8

    # Shuffle
    shuffle_resp = await client.post(f"/api/v1/seating/class/{class_id}/shuffle", headers=h, json={})
    assert shuffle_resp.status_code == 200
    assert shuffle_resp.json()["success"] is True

    # Update seating
    update_resp = await client.put(
        f"/api/v1/seating/class/{class_id}", headers=h,
        json={"rows": 3, "cols": 4})
    assert update_resp.status_code == 200
    assert update_resp.json()["rows"] == 3


async def test_schedule_crud(client, monkeypatch):
    h = await _login(client, "13900005555", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "课表班", "grade": "四"})
    class_id = cls.json()["id"]

    # Create schedule
    create_resp = await client.post("/api/v1/schedules", headers=h,
                                    json={"class_id": class_id, "day_of_week": 1,
                                          "period": 1, "subject": "语文", "teacher_name": "王老师"})
    assert create_resp.status_code == 200
    schedule_id = create_resp.json()["id"]

    # List
    list_resp = await client.get(f"/api/v1/schedules/class/{class_id}", headers=h)
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1

    # Delete
    del_resp = await client.delete(f"/api/v1/schedules/{schedule_id}", headers=h)
    assert del_resp.status_code == 200

    # Dashboard: schedule_count should be 0
    dash = await client.get(f"/api/v1/dashboard/class/{class_id}", headers=h)
    assert dash.json()["schedule_count"] == 0
