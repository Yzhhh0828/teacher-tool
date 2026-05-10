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


def test_ensure_backward_compatible_schema_adds_missing_student_columns(tmp_path):
    """Regression for the 500 error caused by adding extended fields to the
    Student model without a column-level migration."""
    db_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{db_path}")

    with engine.begin() as conn:
        # Pre-existing students table from before the extension.
        conn.execute(
            text(
                """
                CREATE TABLE students (
                    id INTEGER PRIMARY KEY,
                    class_id INTEGER NOT NULL,
                    name VARCHAR(100) NOT NULL,
                    gender VARCHAR(10) NOT NULL,
                    phone VARCHAR(20),
                    parent_phone VARCHAR(20),
                    remarks TEXT,
                    created_at DATETIME
                )
                """
            )
        )
        # Other tables also need to exist so the inspector doesn't bail out.
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
    columns = {c["name"] for c in inspector.get_columns("students")}
    for expected in (
        "student_no",
        "birthday",
        "parent_name",
        "address",
        "home_phone",
        "hobbies",
        "health",
        "emergency_contact",
        "description",
    ):
        assert expected in columns, f"missing column {expected}"


def test_ensure_backward_compatible_schema_is_idempotent(tmp_path):
    """Running the migration twice in a row must not raise (no duplicate
    ADD COLUMN errors)."""
    db_path = tmp_path / "idempotent.db"
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
        # Second pass: should be a no-op since all columns exist.
        ensure_backward_compatible_schema(conn)


def test_ensure_backward_compatible_schema_skips_empty_database(tmp_path):
    """A brand-new database (no tables yet) must be left untouched so
    create_all() can run cleanly afterwards."""
    db_path = tmp_path / "empty.db"
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        ensure_backward_compatible_schema(conn)
    inspector = inspect(engine)
    assert inspector.get_table_names() == []
