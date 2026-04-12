import pytest
import pytest_asyncio
from datetime import datetime
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, selectinload
from app.database import Base
from app.models.user import User
from app.models.class_ import Class, ClassMember


@pytest_asyncio.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with async_session() as session:
        yield session


@pytest.mark.asyncio
async def test_create_user(db_session):
    user = User(phone="13800138000", password_hash="hashed_password")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    assert user.id is not None
    assert user.phone == "13800138000"
    assert user.created_at is not None


@pytest.mark.asyncio
async def test_create_class_with_owner(db_session):
    user = User(phone="13800138000", password_hash="hashed_password")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    class_ = Class(name="一年级一班", grade="一年级", owner_id=user.id)
    db_session.add(class_)
    await db_session.commit()
    await db_session.refresh(class_)

    assert class_.id is not None
    assert class_.name == "一年级一班"
    assert class_.owner_id == user.id


@pytest.mark.asyncio
async def test_class_member_relationship(db_session):
    user = User(phone="13800138000", password_hash="hashed_password")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    class_ = Class(name="一年级一班", grade="一年级", owner_id=user.id)
    db_session.add(class_)
    await db_session.commit()
    await db_session.refresh(class_)

    member = ClassMember(class_id=class_.id, user_id=user.id, role="owner")
    db_session.add(member)
    await db_session.commit()
    await db_session.refresh(member)

    assert member.id is not None
    assert member.role == "owner"
    assert member.class_id == class_.id

    # Test relationship traversal - load relationships explicitly in async context
    from sqlalchemy import select
    result = await db_session.execute(
        select(User).options(selectinload(User.owned_classes)).where(User.id == user.id)
    )
    user_with_classes = result.scalar_one()
    assert class_ in user_with_classes.owned_classes

    result = await db_session.execute(
        select(ClassMember).options(selectinload(ClassMember.class_), selectinload(ClassMember.user)).where(ClassMember.id == member.id)
    )
    member_with_relations = result.scalar_one()
    assert member_with_relations.class_ == class_
    assert member_with_relations.user == user
