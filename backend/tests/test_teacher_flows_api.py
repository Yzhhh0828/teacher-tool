import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.auth import router as auth_router, verification_store
from app.api.class_ import router as class_router
from app.api.students import router as students_router
from app.api.grades import router as grades_router
from app.api.seating import router as seating_router
from app.api.schedules import router as schedules_router
from app.config import settings
from app.database import Base, get_db


@pytest_asyncio.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session):
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
    ) as async_client:
        yield async_client


async def _login(client: AsyncClient, phone: str) -> dict:
    send_code_response = await client.post(
        "/api/v1/auth/send_code",
        json={"phone": phone},
    )
    debug_code = send_code_response.json()["debug_code"]
    login_response = await client.post(
        "/api/v1/auth/login",
        json={"phone": phone, "code": debug_code},
    )
    return login_response.json()


@pytest.mark.asyncio
async def test_owner_can_create_class_and_manage_teaching_flow(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    owner_tokens = await _login(client, "13800138010")
    owner_headers = {"Authorization": f"Bearer {owner_tokens['access_token']}"}

    create_class_response = await client.post(
        "/api/v1/classes",
        headers=owner_headers,
        json={"name": "高一(1)班", "grade": "高一"},
    )
    assert create_class_response.status_code == 200
    class_id = create_class_response.json()["id"]

    invite_response = await client.post(
        f"/api/v1/classes/{class_id}/invite_code",
        headers=owner_headers,
    )
    assert invite_response.status_code == 200
    invite_code = invite_response.json()["invite_code"]

    teacher_tokens = await _login(client, "13800138011")
    teacher_headers = {"Authorization": f"Bearer {teacher_tokens['access_token']}"}

    join_response = await client.post(
        "/api/v1/classes/join",
        headers=teacher_headers,
        json={"invite_code": invite_code, "subject": "数学"},
    )
    assert join_response.status_code == 200

    student_response = await client.post(
        "/api/v1/students",
        headers=owner_headers,
        json={
            "class_id": class_id,
            "name": "张三",
            "gender": "male",
            "phone": "13800000000",
            "parent_phone": "13900000000",
            "remarks": "测试学生",
        },
    )
    assert student_response.status_code == 200
    student_id = student_response.json()["id"]

    exam_response = await client.post(
        "/api/v1/grades/exams",
        headers=owner_headers,
        json={"class_id": class_id, "name": "期中考试", "date": "2026-04-13T10:00:00"},
    )
    assert exam_response.status_code == 200
    exam_id = exam_response.json()["id"]

    grade_response = await client.post(
        "/api/v1/grades",
        headers=teacher_headers,
        json={
            "exam_id": exam_id,
            "student_id": student_id,
            "subject": "数学",
            "score": 98,
            "remarks": "发挥稳定",
        },
    )
    assert grade_response.status_code == 200
    assert grade_response.json()["subject"] == "数学"

    grades_response = await client.get(
        f"/api/v1/grades/exams/{exam_id}",
        headers=owner_headers,
    )
    assert grades_response.status_code == 200
    assert grades_response.json()[0]["student_id"] == student_id
    assert "created_at" in grade_response.json()

    delete_exam_response = await client.delete(
        f"/api/v1/grades/exams/{exam_id}",
        headers=owner_headers,
    )
    assert delete_exam_response.status_code == 200

    exams_after_delete = await client.get(
        f"/api/v1/grades/exams/class/{class_id}",
        headers=owner_headers,
    )
    assert exams_after_delete.status_code == 200
    assert exams_after_delete.json() == []


@pytest.mark.asyncio
async def test_seating_flow_returns_full_model_and_updates_seat_matrix(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    owner_tokens = await _login(client, "13800138012")
    owner_headers = {"Authorization": f"Bearer {owner_tokens['access_token']}"}

    create_class_response = await client.post(
        "/api/v1/classes",
        headers=owner_headers,
        json={"name": "高一(2)班", "grade": "高一"},
    )
    class_id = create_class_response.json()["id"]

    student_one = await client.post(
        "/api/v1/students",
        headers=owner_headers,
        json={"class_id": class_id, "name": "李雷", "gender": "male"},
    )
    student_two = await client.post(
        "/api/v1/students",
        headers=owner_headers,
        json={"class_id": class_id, "name": "韩梅梅", "gender": "female"},
    )

    seating_response = await client.get(
        f"/api/v1/seating/class/{class_id}",
        headers=owner_headers,
    )
    assert seating_response.status_code == 200
    seating_body = seating_response.json()
    assert seating_body["rows"] == 6
    assert seating_body["cols"] == 8
    assert seating_body["id"] is not None
    assert seating_body["class_id"] == class_id

    updated_seats = seating_body["seats"]
    updated_seats[0][0] = student_one.json()["id"]
    updated_seats[0][1] = student_two.json()["id"]

    update_response = await client.put(
        f"/api/v1/seating/class/{class_id}",
        headers=owner_headers,
        json={"rows": 6, "cols": 8, "seats": updated_seats},
    )
    assert update_response.status_code == 200
    assert update_response.json()["seats"][0][0] == student_one.json()["id"]
    assert update_response.json()["seats"][0][1] == student_two.json()["id"]

    shuffle_response = await client.post(
        f"/api/v1/seating/class/{class_id}/shuffle",
        headers=owner_headers,
    )
    assert shuffle_response.status_code == 200
    assert shuffle_response.json()["success"] is True
    assert len(shuffle_response.json()["seats"]) == 6


@pytest.mark.asyncio
async def test_teacher_can_update_existing_grade_without_subject_override(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    owner_tokens = await _login(client, "13800138013")
    owner_headers = {"Authorization": f"Bearer {owner_tokens['access_token']}"}
    teacher_tokens = await _login(client, "13800138014")
    teacher_headers = {"Authorization": f"Bearer {teacher_tokens['access_token']}"}

    create_class_response = await client.post(
        "/api/v1/classes",
        headers=owner_headers,
        json={"name": "高一(3)班", "grade": "高一"},
    )
    class_id = create_class_response.json()["id"]

    invite_response = await client.post(
        f"/api/v1/classes/{class_id}/invite_code",
        headers=owner_headers,
    )
    invite_code = invite_response.json()["invite_code"]

    await client.post(
        "/api/v1/classes/join",
        headers=teacher_headers,
        json={"invite_code": invite_code, "subject": "英语"},
    )

    student_response = await client.post(
        "/api/v1/students",
        headers=owner_headers,
        json={"class_id": class_id, "name": "王五", "gender": "male"},
    )
    exam_response = await client.post(
        "/api/v1/grades/exams",
        headers=owner_headers,
        json={"class_id": class_id, "name": "月考", "date": "2026-04-14T10:00:00"},
    )
    grade_response = await client.post(
        "/api/v1/grades",
        headers=teacher_headers,
        json={
            "exam_id": exam_response.json()["id"],
            "student_id": student_response.json()["id"],
            "subject": "英语",
            "score": 85,
            "remarks": "初始分数",
        },
    )

    update_response = await client.put(
        f"/api/v1/grades/{grade_response.json()['id']}",
        headers=teacher_headers,
        json={"score": 91, "remarks": "修正后"},
    )

    assert update_response.status_code == 200
    assert update_response.json()["score"] == 91


@pytest.mark.asyncio
async def test_schedule_flow_can_create_list_and_delete_schedule(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    owner_tokens = await _login(client, "13800138015")
    owner_headers = {"Authorization": f"Bearer {owner_tokens['access_token']}"}

    create_class_response = await client.post(
        "/api/v1/classes",
        headers=owner_headers,
        json={"name": "高一(4)班", "grade": "高一"},
    )
    class_id = create_class_response.json()["id"]

    create_schedule_response = await client.post(
        "/api/v1/schedules",
        headers=owner_headers,
        json={
            "class_id": class_id,
            "day_of_week": 0,
            "period": 1,
            "subject": "语文",
            "teacher_name": "李老师",
            "classroom": "101",
        },
    )

    assert create_schedule_response.status_code == 200
    schedule_id = create_schedule_response.json()["id"]

    list_schedule_response = await client.get(
        f"/api/v1/schedules/class/{class_id}",
        headers=owner_headers,
    )
    assert list_schedule_response.status_code == 200
    assert list_schedule_response.json()[0]["subject"] == "语文"

    delete_schedule_response = await client.delete(
        f"/api/v1/schedules/{schedule_id}",
        headers=owner_headers,
    )
    assert delete_schedule_response.status_code == 200
