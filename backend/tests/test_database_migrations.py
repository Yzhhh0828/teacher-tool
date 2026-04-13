from sqlalchemy import create_engine, inspect, text

from app.database import ensure_backward_compatible_schema


def test_ensure_backward_compatible_schema_adds_missing_class_columns(tmp_path):
    db_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{db_path}")

    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE classes (
                    id INTEGER PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    grade VARCHAR(50) NOT NULL,
                    owner_id INTEGER NOT NULL,
                    created_at DATETIME
                )
                """
            )
        )
        ensure_backward_compatible_schema(conn)

    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns("classes")}
    assert "invite_code" in columns
    assert "invite_expires_at" in columns
