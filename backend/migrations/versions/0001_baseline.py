"""Baseline schema — full snapshot of every table currently used by the app.

Implementation note: rather than maintain a hand-coded ``CREATE TABLE`` for
every model (which drifts out of sync with the ORM), this revision calls
``Base.metadata.create_all`` on the live connection. ``create_all`` is
idempotent and only creates tables that don't already exist, which makes
this a safe baseline for both fresh databases and installs that previously
came up via ``init_db()``.

For new tables added after this baseline, generate a regular alembic
revision with ``alembic revision -m '...'`` and use ``op.create_table``
explicitly so the change history stays auditable.

Revision ID: 0001_baseline
Revises:
Create Date: 2026-05-08
"""
from __future__ import annotations

from alembic import op

from app.database import Base
import app.models  # noqa: F401  (registers all models on Base.metadata)


revision = "0001_baseline"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
