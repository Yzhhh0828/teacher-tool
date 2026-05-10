"""Tests for agent tool registry + key tool handlers."""
from __future__ import annotations

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.agent.tools import registry  # triggers tool registrations
from app.database import Base
from app.models.class_ import Class, ClassMember
from app.models.user import User
from app.models.student import Student


# Per-test asyncio markers below


@pytest.fixture
async def db():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        # Seed: user + class + membership
        user = User(phone="13900000001", password_hash="x")
        session.add(user)
        await session.flush()
        cls = Class(name="C1", grade="G1", owner_id=user.id)
        session.add(cls)
        await session.flush()
        session.add(ClassMember(class_id=cls.id, user_id=user.id, role="owner"))
        await session.commit()
        yield session, user.id, cls.id
    await engine.dispose()


def test_registry_lists_expected_tools():
    names = {t.name for t in registry.all()}
    expected = {
        "list_students", "add_student", "bulk_create_students", "update_student", "delete_student",
        "list_grades", "add_grade", "bulk_upsert_grades",
        "get_seating", "apply_seating_layout", "random_shuffle_seats",
        "analyze_class_performance", "student_trend",
        "pick_random_student", "random_groups",
        "parse_student_roster_image", "parse_seating_chart_image", "parse_grade_sheet_image",
    }
    missing = expected - names
    assert not missing, f"missing tools: {missing}"


def test_write_tools_require_confirmation():
    write = {"add_student", "bulk_create_students", "update_student", "delete_student",
             "add_grade", "bulk_upsert_grades", "apply_seating_layout", "random_shuffle_seats"}
    for name in write:
        t = registry.get(name)
        assert t is not None and t.requires_confirmation, name


@pytest.mark.asyncio
async def test_bulk_create_students(db):
    session, user_id, class_id = db
    result = await registry.invoke(
        "bulk_create_students",
        db=session,
        user_id=user_id,
        class_id=class_id,
        items=[
            {"name": "A", "gender": "male"},
            {"name": "B", "gender": "female"},
            {"name": "A", "gender": "male"},  # duplicate -> skipped
        ],
    )
    assert result["created"] == 2
    assert result["skipped"] == 1


@pytest.mark.asyncio
async def test_pick_random_student(db):
    session, user_id, class_id = db
    # seed students
    for n in ("A", "B", "C"):
        session.add(Student(class_id=class_id, name=n, gender="male"))
    await session.commit()
    result = await registry.invoke(
        "pick_random_student", db=session, user_id=user_id, class_id=class_id
    )
    assert result["picked"]["name"] in ("A", "B", "C")


@pytest.mark.asyncio
async def test_random_groups(db):
    session, user_id, class_id = db
    for n in list("ABCDEFG"):
        session.add(Student(class_id=class_id, name=n, gender="female"))
    await session.commit()
    result = await registry.invoke(
        "random_groups", db=session, user_id=user_id, class_id=class_id, group_size=3, shuffle_seed=1
    )
    assert result["total"] == 7
    sizes = [len(g) for g in result["groups"]]
    assert sum(sizes) == 7
    assert max(sizes) == 3
