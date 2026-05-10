"""Add seating_layouts table for multiple named seating plans.

Revision ID: 0003
Revises: 0002
"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "seating_layouts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("class_id", sa.Integer(), sa.ForeignKey("classes.id"), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("rows", sa.Integer(), server_default="6", nullable=False),
        sa.Column("cols", sa.Integer(), server_default="8", nullable=False),
        sa.Column("seats", sa.JSON(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("seating_layouts")
