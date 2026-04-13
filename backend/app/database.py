from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy import inspect
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""
    pass


# Create async engine based on database URL
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True,
)

# Create async session factory
async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncSession:
    """Dependency to get database session."""
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db() -> None:
    """Initialize database tables."""
    async with engine.begin() as conn:
        await conn.run_sync(ensure_backward_compatible_schema)
        await conn.run_sync(Base.metadata.create_all)


async def close_db() -> None:
    """Close database connections."""
    await engine.dispose()


def ensure_backward_compatible_schema(sync_conn) -> None:
    inspector = inspect(sync_conn)
    if "classes" not in inspector.get_table_names():
        return

    existing_columns = {column["name"] for column in inspector.get_columns("classes")}
    missing_columns = []

    if "invite_code" not in existing_columns:
        missing_columns.append("ALTER TABLE classes ADD COLUMN invite_code VARCHAR(64)")

    if "invite_expires_at" not in existing_columns:
        missing_columns.append("ALTER TABLE classes ADD COLUMN invite_expires_at DATETIME")

    for statement in missing_columns:
        sync_conn.exec_driver_sql(statement)
