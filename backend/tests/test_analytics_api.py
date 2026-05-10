"""Tests for the analytics endpoints — overview, distribution, trend, compare."""
from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.analytics import router as analytics_router
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
    for r in (auth_router, class_router, students_router, grades_router, analytics_router):
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


async def _setup_class_with_grades(client, h):
    """Create a class, students, exam, and grades. Returns (class_id, exam_id, student_ids)."""
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "分析班", "grade": "三"})
    class_id = cls.json()["id"]

    s1 = await client.post("/api/v1/students", headers=h,
                           json={"class_id": class_id, "name": "甲", "gender": "male"})
    s2 = await client.post("/api/v1/students", headers=h,
                           json={"class_id": class_id, "name": "乙", "gender": "female"})
    s3 = await client.post("/api/v1/students", headers=h,
                           json={"class_id": class_id, "name": "丙", "gender": "male"})
    student_ids = [s1.json()["id"], s2.json()["id"], s3.json()["id"]]

    exam = await client.post("/api/v1/grades/exams", headers=h,
                             json={"class_id": class_id, "name": "期中", "date": "2026-04-15T08:00:00"})
    exam_id = exam.json()["id"]

    for sid, score in zip(student_ids, [90, 75, 82]):
        await client.post("/api/v1/grades", headers=h,
                          json={"exam_id": exam_id, "student_id": sid, "subject": "数学", "score": score})

    return class_id, exam_id, student_ids


async def test_class_overview_with_grades(client, monkeypatch):
    h = await _login(client, "13911110001", monkeypatch)
    class_id, exam_id, _ = await _setup_class_with_grades(client, h)

    resp = await client.get(f"/api/v1/analytics/class/{class_id}/overview", headers=h)
    assert resp.status_code == 200
    body = resp.json()
    assert body["student_count"] == 3
    assert body["exam_count"] == 1
    assert body["last_exam"]["id"] == exam_id
    assert "数学" in body["last_exam"]["stats"]
    assert body["last_exam"]["stats"]["数学"]["count"] == 3
    assert body["last_exam"]["stats"]["数学"]["mean"] > 0
    assert body["gender_split"]["male"] == 2
    assert body["gender_split"]["female"] == 1


async def test_class_overview_empty(client, monkeypatch):
    h = await _login(client, "13911110002", monkeypatch)
    cls = await client.post("/api/v1/classes", headers=h, json={"name": "空班", "grade": "一"})
    class_id = cls.json()["id"]

    resp = await client.get(f"/api/v1/analytics/class/{class_id}/overview", headers=h)
    assert resp.status_code == 200
    assert resp.json()["student_count"] == 0
    assert resp.json()["last_exam"] is None


async def test_exam_distribution(client, monkeypatch):
    h = await _login(client, "13911110003", monkeypatch)
    class_id, exam_id, _ = await _setup_class_with_grades(client, h)

    resp = await client.get(f"/api/v1/analytics/exam/{exam_id}/distribution", headers=h)
    assert resp.status_code == 200
    body = resp.json()
    assert "数学" in body["subjects"]
    stats = body["subjects"]["数学"]["stats"]
    assert stats["count"] == 3
    assert stats["min"] == 75
    assert stats["max"] == 90
    buckets = body["subjects"]["数学"]["buckets"]
    assert len(buckets) > 0


async def test_exam_distribution_not_found(client, monkeypatch):
    h = await _login(client, "13911110004", monkeypatch)
    resp = await client.get("/api/v1/analytics/exam/9999/distribution", headers=h)
    assert resp.status_code == 404


async def test_student_trend(client, monkeypatch):
    h = await _login(client, "13911110005", monkeypatch)
    class_id, exam_id, student_ids = await _setup_class_with_grades(client, h)

    resp = await client.get(f"/api/v1/analytics/student/{student_ids[0]}/trend", headers=h)
    assert resp.status_code == 200
    body = resp.json()
    assert body["student"]["name"] == "甲"
    assert "数学" in body["subjects"]
    assert len(body["subjects"]["数学"]) == 1
    assert body["subjects"]["数学"][0]["score"] == 90


async def test_student_trend_not_found(client, monkeypatch):
    h = await _login(client, "13911110006", monkeypatch)
    resp = await client.get("/api/v1/analytics/student/9999/trend", headers=h)
    assert resp.status_code == 404


async def test_compare_class_exams(client, monkeypatch):
    h = await _login(client, "13911110007", monkeypatch)
    class_id, exam_id, student_ids = await _setup_class_with_grades(client, h)

    # Add a second exam
    exam2 = await client.post("/api/v1/grades/exams", headers=h,
                              json={"class_id": class_id, "name": "期末", "date": "2026-06-20T08:00:00"})
    exam2_id = exam2.json()["id"]
    for sid, score in zip(student_ids, [95, 80, 88]):
        await client.post("/api/v1/grades", headers=h,
                          json={"exam_id": exam2_id, "student_id": sid, "subject": "数学", "score": score})

    resp = await client.get(f"/api/v1/analytics/class/{class_id}/compare", headers=h)
    assert resp.status_code == 200
    series = resp.json()["series"]
    assert len(series) == 2
    assert series[0]["exam_name"] == "期中"
    assert series[1]["exam_name"] == "期末"
    assert series[1]["mean"] > series[0]["mean"]


async def test_compare_with_subject_filter(client, monkeypatch):
    h = await _login(client, "13911110008", monkeypatch)
    class_id, exam_id, student_ids = await _setup_class_with_grades(client, h)

    # Filter by nonexistent subject
    resp = await client.get(
        f"/api/v1/analytics/class/{class_id}/compare?subject=英语", headers=h)
    assert resp.status_code == 200
    assert resp.json()["series"] == []

    # Filter by existing subject
    resp = await client.get(
        f"/api/v1/analytics/class/{class_id}/compare?subject=数学", headers=h)
    assert resp.status_code == 200
    assert len(resp.json()["series"]) == 1
