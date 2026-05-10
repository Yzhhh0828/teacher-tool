"""Add extended student fields: student_no, birthday, parent_name, address,
home_phone, hobbies, health, emergency_contact, description.

Revision ID: 0002_student_extended_fields
Revises: 0001_baseline
Create Date: 2026-05-09
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0002_student_extended_fields"
down_revision = "0001_baseline"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("students") as batch_op:
        batch_op.add_column(sa.Column("student_no", sa.String(50), nullable=True))
        batch_op.add_column(sa.Column("birthday", sa.Date(), nullable=True))
        batch_op.add_column(sa.Column("parent_name", sa.String(100), nullable=True))
        batch_op.add_column(sa.Column("address", sa.String(300), nullable=True))
        batch_op.add_column(sa.Column("home_phone", sa.String(20), nullable=True))
        batch_op.add_column(sa.Column("hobbies", sa.String(300), nullable=True))
        batch_op.add_column(sa.Column("health", sa.String(300), nullable=True))
        batch_op.add_column(sa.Column("emergency_contact", sa.String(100), nullable=True))
        batch_op.add_column(sa.Column("description", sa.Text(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("students") as batch_op:
        batch_op.drop_column("description")
        batch_op.drop_column("emergency_contact")
        batch_op.drop_column("health")
        batch_op.drop_column("hobbies")
        batch_op.drop_column("home_phone")
        batch_op.drop_column("address")
        batch_op.drop_column("parent_name")
        batch_op.drop_column("birthday")
        batch_op.drop_column("student_no")
