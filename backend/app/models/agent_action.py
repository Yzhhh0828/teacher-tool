"""Audit log for AI agent actions — supports undo/replay."""
from datetime import datetime, UTC
from typing import Any
from sqlalchemy import String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class AgentAction(Base):
    __tablename__ = "agent_actions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    action_type: Mapped[str] = mapped_column(String(64))  # e.g. bulk_create_students
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    diff: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)  # {created: n, updated: n, skipped: n}
    undo_payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)  # info needed to undo
    status: Mapped[str] = mapped_column(String(20), default="committed")  # pending/committed/undone/failed
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
