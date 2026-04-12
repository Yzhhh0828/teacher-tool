from datetime import datetime, UTC
from typing import Any
from sqlalchemy import Integer, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Seating(Base):
    __tablename__ = "seatings"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"), unique=True)
    rows: Mapped[int] = mapped_column(Integer, default=6)
    cols: Mapped[int] = mapped_column(Integer, default=8)
    seats: Mapped[list[Any]] = mapped_column(JSON, default=list)  # 2D array of student IDs
    updated_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC)
    )

    class_: Mapped["Class"] = relationship("Class", back_populates="seating")
