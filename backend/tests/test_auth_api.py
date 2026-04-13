import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.auth import router as auth_router, verification_store
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

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    verification_store._entries.clear()

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://testserver",
    ) as async_client:
        yield async_client


@pytest.mark.asyncio
async def test_send_code_returns_debug_code_in_debug_mode(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    response = await client.post(
        "/api/v1/auth/send_code",
        json={"phone": "13800138000"},
    )

    assert response.status_code == 200
    assert response.json()["debug_code"] == settings.DEV_FIXED_VERIFICATION_CODE


@pytest.mark.asyncio
async def test_send_code_hides_debug_code_when_disabled(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", False)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", False)

    response = await client.post(
        "/api/v1/auth/send_code",
        json={"phone": "13800138001"},
    )

    assert response.status_code == 200
    assert "debug_code" not in response.json()


@pytest.mark.asyncio
async def test_login_and_refresh_work_with_issued_code(client, monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(settings, "EXPOSE_DEBUG_VERIFICATION_CODE", True)

    send_code_response = await client.post(
        "/api/v1/auth/send_code",
        json={"phone": "13800138002"},
    )
    debug_code = send_code_response.json()["debug_code"]

    login_response = await client.post(
        "/api/v1/auth/login",
        json={"phone": "13800138002", "code": debug_code},
    )

    assert login_response.status_code == 200
    tokens = login_response.json()
    assert "access_token" in tokens
    assert "refresh_token" in tokens

    refresh_response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )

    assert refresh_response.status_code == 200
    refreshed_tokens = refresh_response.json()
    assert "access_token" in refreshed_tokens
    assert "refresh_token" in refreshed_tokens
