"""Student behavior tracking: categories (preset + custom) and per-student records."""
from datetime import datetime, UTC
from sqlalchemy import String, DateTime, Float, ForeignKey, Text, Boolean, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class BehaviorCategory(Base):
    __tablename__ = "behavior_categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    name: Mapped[str] = mapped_column(String(50))
    icon: Mapped[str] = mapped_column(String(32), default="star")
    score: Mapped[float] = mapped_column(Float, default=1.0)
    is_preset: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    records: Mapped[list["BehaviorRecord"]] = relationship(
        "BehaviorRecord", back_populates="category", cascade="all, delete-orphan"
    )


class BehaviorRecord(Base):
    __tablename__ = "behavior_records"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"), index=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("behavior_categories.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    score: Mapped[float] = mapped_column(Float)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), index=True)

    category: Mapped["BehaviorCategory"] = relationship("BehaviorCategory", back_populates="records")
