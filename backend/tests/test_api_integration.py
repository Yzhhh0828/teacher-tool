"""
Full-stack API integration tests.
Covers: auth, class, student, exam/grade, seating, schedule.
Uses an in-memory SQLite database with StaticPool so all connections share
the same database instance throughout each test.
"""
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.students import router as students_router
from app.api.grades import router as grades_router
from app.api.seating import router as seating_router
from app.api.schedules import router as schedules_router
from app.config import settings
from app.database import Base, get_db


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
async def db_session():
    """Shared in-memory SQLite session used by all requests within a test."""
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
async def app_client(db_session):
    """AsyncClient wired to a minimal FastAPI app with all routers and shared DB."""
    app = FastAPI()
    app.include_router(auth_router, prefix="/api/v1")
    app.include_router(class_router, prefix="/api/v1")
    app.include_router(students_router, prefix="/api/v1")
    app.include_router(grades_router, prefix="/api/v1")
    app.include_router(seating_router, prefix="/api/v1")
    app.include_router(schedules_router, prefix="/api/v1")

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    verification_store._entries.clear()

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://testserver",
    ) as client:
        yield client


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def register_and_login(client: AsyncClient, phone: str, monkeypatch) -> dict:
    """Issue a verification code and log in; return auth headers."""
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    resp = await client.post("/api/v1/auth/send_code", json={"phone": phone})
    assert resp.status_code == 200
    code = resp.json()["debug_code"]

    resp = await client.post("/api/v1/auth/login", json={"phone": phone, "code": code})
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

async def test_auth_send_code_returns_debug_code(app_client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    resp = await app_client.post("/api/v1/auth/send_code", json={"phone": "13800000001"})
    assert resp.status_code == 200
    assert "debug_code" in resp.json()


async def test_auth_login_with_wrong_code_fails(app_client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    await app_client.post("/api/v1/auth/send_code", json={"phone": "13800000002"})

    resp = await app_client.post(
        "/api/v1/auth/login",
        json={"phone": "13800000002", "code": "000000"},
    )
    assert resp.status_code == 400


async def test_auth_token_refresh(app_client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    resp = await app_client.post("/api/v1/auth/send_code", json={"phone": "13800000003"})
    code = resp.json()["debug_code"]
    login = await app_client.post(
        "/api/v1/auth/login", json={"phone": "13800000003", "code": code}
    )
    tokens = login.json()

    refresh = await app_client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refresh.status_code == 200
    assert "access_token" in refresh.json()


async def test_get_me_requires_auth(app_client):
    resp = await app_client.get("/api/v1/auth/me")
    assert resp.status_code == 401


async def test_get_me_returns_user(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13800000010", monkeypatch)
    resp = await app_client.get("/api/v1/auth/me", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["phone"] == "13800000010"


# ---------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------

async def test_create_and_list_class(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13810000001", monkeypatch)

    create = await app_client.post(
        "/api/v1/classes",
        headers=headers,
        json={"name": "三年级一班", "grade": "三年级"},
    )
    assert create.status_code == 200
    class_id = create.json()["id"]

    lst = await app_client.get("/api/v1/classes", headers=headers)
    assert lst.status_code == 200
    ids = [c["id"] for c in lst.json()]
    assert class_id in ids


async def test_invite_code_and_join(app_client, monkeypatch):
    owner_headers = await register_and_login(app_client, "13810000002", monkeypatch)
    teacher_headers = await register_and_login(app_client, "13810000003", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes",
        headers=owner_headers,
        json={"name": "四年级二班", "grade": "四年级"},
    )
    class_id = cls.json()["id"]

    invite = await app_client.post(
        f"/api/v1/classes/{class_id}/invite_code",
        headers=owner_headers,
    )
    assert invite.status_code == 200
    invite_code = invite.json()["invite_code"]

    join = await app_client.post(
        "/api/v1/classes/join",
        headers=teacher_headers,
        json={"invite_code": invite_code, "subject": "数学"},
    )
    assert join.status_code == 200

    # joining again should fail
    join2 = await app_client.post(
        "/api/v1/classes/join",
        headers=teacher_headers,
        json={"invite_code": invite_code, "subject": "数学"},
    )
    assert join2.status_code == 400


async def test_non_member_cannot_access_class(app_client, monkeypatch):
    owner_headers = await register_and_login(app_client, "13810000004", monkeypatch)
    other_headers = await register_and_login(app_client, "13810000005", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes",
        headers=owner_headers,
        json={"name": "五年级三班", "grade": "五年级"},
    )
    class_id = cls.json()["id"]

    resp = await app_client.get(f"/api/v1/classes/{class_id}", headers=other_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Students
# ---------------------------------------------------------------------------

async def test_create_and_list_students(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13820000001", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes",
        headers=headers,
        json={"name": "六年级一班", "grade": "六年级"},
    )
    class_id = cls.json()["id"]

    student = await app_client.post(
        "/api/v1/students",
        headers=headers,
        json={"class_id": class_id, "name": "张三", "gender": "male"},
    )
    assert student.status_code == 200
    student_id = student.json()["id"]

    lst = await app_client.get(
        f"/api/v1/students/class/{class_id}", headers=headers
    )
    assert lst.status_code == 200
    ids = [s["id"] for s in lst.json()]
    assert student_id in ids


async def test_student_nullable_fields_accepted(app_client, monkeypatch):
    """phone, parent_phone, remarks should accept null (B1 regression test)."""
    headers = await register_and_login(app_client, "13820000002", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes",
        headers=headers,
        json={"name": "测试班", "grade": "初一"},
    )
    class_id = cls.json()["id"]

    resp = await app_client.post(
        "/api/v1/students",
        headers=headers,
        json={
            "class_id": class_id,
            "name": "李四",
            "gender": "female",
            "phone": None,
            "parent_phone": None,
            "remarks": None,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["phone"] is None
    assert data["parent_phone"] is None
    assert data["remarks"] is None


async def test_delete_student(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13820000003", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes",
        headers=headers,
        json={"name": "删除测试班", "grade": "初二"},
    )
    class_id = cls.json()["id"]

    s = await app_client.post(
        "/api/v1/students",
        headers=headers,
        json={"class_id": class_id, "name": "王五", "gender": "male"},
    )
    student_id = s.json()["id"]

    del_resp = await app_client.delete(
        f"/api/v1/students/{student_id}", headers=headers
    )
    assert del_resp.status_code == 200

    lst = await app_client.get(
        f"/api/v1/students/class/{class_id}", headers=headers
    )
    assert all(s["id"] != student_id for s in lst.json())


# ---------------------------------------------------------------------------
# Exam & Grade
# ---------------------------------------------------------------------------

async def test_create_exam_and_grade(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13830000001", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes",
        headers=headers,
        json={"name": "成绩测试班", "grade": "初三"},
    )
    class_id = cls.json()["id"]

    s = await app_client.post(
        "/api/v1/students",
        headers=headers,
        json={"class_id": class_id, "name": "测试生", "gender": "male"},
    )
    student_id = s.json()["id"]

    exam = await app_client.post(
        "/api/v1/grades/exams",
        headers=headers,
        json={"class_id": class_id, "name": "期末考试", "date": "2025-06-20T00:00:00"},
    )
    assert exam.status_code == 200
    exam_id = exam.json()["id"]

    grade = await app_client.post(
        "/api/v1/grades",
        headers=headers,
        json={
            "exam_id": exam_id,
            "student_id": student_id,
            "subject": "语文",
            "score": 95.5,
        },
    )
    assert grade.status_code == 200
    assert grade.json()["score"] == 95.5


async def test_grade_cross_class_student_rejected(app_client, monkeypatch):
    """B4 regression: student from a different class must be rejected (400)."""
    headers = await register_and_login(app_client, "13830000002", monkeypatch)

    cls_a = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "班级A", "grade": "高一"},
    )
    cls_b = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "班级B", "grade": "高一"},
    )
    class_a_id = cls_a.json()["id"]
    class_b_id = cls_b.json()["id"]

    # Student in class B
    s = await app_client.post(
        "/api/v1/students", headers=headers,
        json={"class_id": class_b_id, "name": "外班生", "gender": "male"},
    )
    student_b_id = s.json()["id"]

    # Exam in class A
    exam = await app_client.post(
        "/api/v1/grades/exams", headers=headers,
        json={"class_id": class_a_id, "name": "跨班考试", "date": "2025-06-20T00:00:00"},
    )
    exam_id = exam.json()["id"]

    # Grade using class-B student in class-A exam — must fail
    resp = await app_client.post(
        "/api/v1/grades", headers=headers,
        json={
            "exam_id": exam_id,
            "student_id": student_b_id,
            "subject": "数学",
            "score": 80.0,
        },
    )
    assert resp.status_code == 400


async def test_duplicate_grade_upserts_score(app_client, monkeypatch):
    """Submitting the same exam+student+subject combo updates score in-place."""
    headers = await register_and_login(app_client, "13830000003", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "更新成绩班", "grade": "高二"},
    )
    class_id = cls.json()["id"]
    s = await app_client.post(
        "/api/v1/students", headers=headers,
        json={"class_id": class_id, "name": "覆盖生", "gender": "female"},
    )
    student_id = s.json()["id"]
    exam = await app_client.post(
        "/api/v1/grades/exams", headers=headers,
        json={"class_id": class_id, "name": "更新考试", "date": "2025-06-21T00:00:00"},
    )
    exam_id = exam.json()["id"]

    await app_client.post(
        "/api/v1/grades", headers=headers,
        json={"exam_id": exam_id, "student_id": student_id, "subject": "英语", "score": 70.0},
    )
    resp2 = await app_client.post(
        "/api/v1/grades", headers=headers,
        json={"exam_id": exam_id, "student_id": student_id, "subject": "英语", "score": 88.0},
    )
    assert resp2.status_code == 200
    assert resp2.json()["score"] == 88.0


# ---------------------------------------------------------------------------
# Seating
# ---------------------------------------------------------------------------

async def test_seating_shuffle_no_duplicates(app_client, monkeypatch):
    """B2 regression: after shuffle seats should not contain duplicate student IDs."""
    headers = await register_and_login(app_client, "13840000001", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "座位测试班", "grade": "初一"},
    )
    class_id = cls.json()["id"]

    # Add 3 students to a 2×3 grid (6 slots, 3 students → 3 slots should be None)
    student_ids = []
    for i in range(3):
        s = await app_client.post(
            "/api/v1/students", headers=headers,
            json={"class_id": class_id, "name": f"学生{i+1}", "gender": "male"},
        )
        student_ids.append(s.json()["id"])

    # Initialise seating grid (2 rows × 3 cols)
    await app_client.put(
        f"/api/v1/seating/class/{class_id}", headers=headers,
        json={"rows": 2, "cols": 3, "seats": [[None]*3, [None]*3]},
    )

    # Shuffle
    shuffle = await app_client.post(
        f"/api/v1/seating/class/{class_id}/shuffle", headers=headers
    )
    assert shuffle.status_code == 200
    seats = shuffle.json()["seats"]

    # Flatten non-None values — must be exactly student_ids with no repetitions
    flat = [cell for row in seats for cell in row if cell is not None]
    assert len(flat) == len(student_ids)
    assert set(flat) == set(student_ids)
    assert len(flat) == len(set(flat)), "Duplicate student IDs detected in shuffled seats"


async def test_seating_shuffle_more_seats_than_students_no_duplicates(app_client, monkeypatch):
    """B2 regression: rows×cols > students should leave extras as None, no repeats."""
    headers = await register_and_login(app_client, "13840000002", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "大座位班", "grade": "高三"},
    )
    class_id = cls.json()["id"]

    # Only 2 students but 3×3 = 9 seats
    student_ids = []
    for i in range(2):
        s = await app_client.post(
            "/api/v1/students", headers=headers,
            json={"class_id": class_id, "name": f"小{i}", "gender": "female"},
        )
        student_ids.append(s.json()["id"])

    await app_client.put(
        f"/api/v1/seating/class/{class_id}", headers=headers,
        json={"rows": 3, "cols": 3, "seats": [[None]*3]*3},
    )

    shuffle = await app_client.post(
        f"/api/v1/seating/class/{class_id}/shuffle", headers=headers
    )
    assert shuffle.status_code == 200
    seats = shuffle.json()["seats"]

    flat = [cell for row in seats for cell in row if cell is not None]
    assert len(flat) == 2
    assert set(flat) == set(student_ids)
    assert len(flat) == len(set(flat)), "Duplicate student IDs after shuffle"


# ---------------------------------------------------------------------------
# Schedules
# ---------------------------------------------------------------------------

async def test_create_and_list_schedules(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13850000001", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "课表测试班", "grade": "初二"},
    )
    class_id = cls.json()["id"]

    create = await app_client.post(
        "/api/v1/schedules", headers=headers,
        json={
            "class_id": class_id,
            "day_of_week": 1,
            "period": 1,
            "subject": "数学",
            "teacher_name": "王老师",
            "classroom": "教室101",
        },
    )
    assert create.status_code == 200
    schedule_id = create.json()["id"]

    lst = await app_client.get(
        f"/api/v1/schedules/class/{class_id}", headers=headers
    )
    assert lst.status_code == 200
    assert any(s["id"] == schedule_id for s in lst.json())


async def test_delete_schedule(app_client, monkeypatch):
    headers = await register_and_login(app_client, "13850000002", monkeypatch)

    cls = await app_client.post(
        "/api/v1/classes", headers=headers,
        json={"name": "删课表班", "grade": "初三"},
    )
    class_id = cls.json()["id"]

    s = await app_client.post(
        "/api/v1/schedules", headers=headers,
        json={"class_id": class_id, "day_of_week": 2, "period": 3, "subject": "英语"},
    )
    schedule_id = s.json()["id"]

    del_resp = await app_client.delete(
        f"/api/v1/schedules/{schedule_id}", headers=headers
    )
    assert del_resp.status_code == 200

    lst = await app_client.get(
        f"/api/v1/schedules/class/{class_id}", headers=headers
    )
    assert all(sc["id"] != schedule_id for sc in lst.json())
