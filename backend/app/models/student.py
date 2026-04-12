from datetime import datetime, UTC
from sqlalchemy import String, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    name: Mapped[str] = mapped_column(String(100))
    gender: Mapped[str] = mapped_column(String(10))  # male, female
    phone: Mapped[str] = mapped_column(String(20), nullable=True)
    parent_phone: Mapped[str] = mapped_column(String(20), nullable=True)
    remarks: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))

    class_: Mapped["Class"] = relationship("Class", back_populates="students")
    grades: Mapped[list["Grade"]] = relationship("Grade", back_populates="student", cascade="all, delete-orphan")
