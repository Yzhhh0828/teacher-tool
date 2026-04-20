from datetime import datetime, UTC
from sqlalchemy import String, DateTime, Float, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Exam(Base):
    __tablename__ = "exams"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    name: Mapped[str] = mapped_column(String(200))
    date: Mapped[datetime] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    class_: Mapped["Class"] = relationship("Class", back_populates="exams")
    grades: Mapped[list["Grade"]] = relationship("Grade", back_populates="exam", cascade="all, delete-orphan")


class Grade(Base):
    __tablename__ = "grades"

    id: Mapped[int] = mapped_column(primary_key=True)
    exam_id: Mapped[int] = mapped_column(ForeignKey("exams.id"))
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id"))
    subject: Mapped[str] = mapped_column(String(50))
    score: Mapped[float] = mapped_column(Float, default=0.0)
    remarks: Mapped[str] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    exam: Mapped["Exam"] = relationship("Exam", back_populates="grades")
    student: Mapped["Student"] = relationship("Student", back_populates="grades")
