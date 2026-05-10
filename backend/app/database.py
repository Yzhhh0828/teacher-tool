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


async def init_db() -> None:
    """Initialize database tables."""
    async with engine.begin() as conn:
        await conn.run_sync(ensure_backward_compatible_schema)
        await conn.run_sync(Base.metadata.create_all)


async def close_db() -> None:
    """Close database connections."""
    await engine.dispose()


def ensure_backward_compatible_schema(sync_conn) -> None:
    """Lightweight, idempotent ALTER TABLE migration for SQLite/Postgres.

    SQLAlchemy's ``create_all`` only adds *new tables*, never new columns. So
    when a model gains a column on an existing deployment, the next request
    that selects that column blows up with ``no such column: ...``. This
    function inspects each table and emits ``ALTER TABLE ADD COLUMN`` for
    any column that lives on the model but is missing from the database.
    """
    inspector = inspect(sync_conn)
    table_names = set(inspector.get_table_names())
    if not table_names:
        return  # fresh database — create_all() will lay it out correctly.

    dialect = sync_conn.dialect.name
    ts_type = "TIMESTAMP" if dialect == "postgresql" else "DATETIME"
    date_type = "DATE"

    # ── Per-table column map: name -> "<TYPE>" ───────────────────────────
    # When you add a *nullable* column to a model, list it here too. The
    # migration is idempotent (skips columns that already exist).
    expected: dict[str, dict[str, str]] = {
        "classes": {
            "invite_code": "VARCHAR(64)",
            "invite_expires_at": ts_type,
        },
        "students": {
            "student_no": "VARCHAR(50)",
            "birthday": date_type,
            "parent_name": "VARCHAR(100)",
            "address": "VARCHAR(300)",
            "home_phone": "VARCHAR(20)",
            "hobbies": "VARCHAR(300)",
            "health": "VARCHAR(300)",
            "emergency_contact": "VARCHAR(100)",
            "description": "TEXT",
        },
        "class_members": {
            "subject": "VARCHAR(50)",
        },
    }

    statements: list[str] = []
    for table, columns in expected.items():
        if table not in table_names:
            continue
        existing = {c["name"] for c in inspector.get_columns(table)}
        for col, sql_type in columns.items():
            if col not in existing:
                statements.append(
                    f"ALTER TABLE {table} ADD COLUMN {col} {sql_type}"
                )

    for statement in statements:
        sync_conn.exec_driver_sql(statement)
