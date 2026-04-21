from datetime import datetime, UTC
from sqlalchemy import String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Class(Base):
    __tablename__ = "classes"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    grade: Mapped[str] = mapped_column(String(50))
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    invite_code: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True)
    invite_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    owner: Mapped["User"] = relationship("User", back_populates="owned_classes")
    members: Mapped[list["ClassMember"]] = relationship("ClassMember", back_populates="class_")
    students: Mapped[list["Student"]] = relationship("Student", back_populates="class_", cascade="all, delete-orphan")
    exams: Mapped[list["Exam"]] = relationship("Exam", back_populates="class_", cascade="all, delete-orphan")
    schedules: Mapped[list["Schedule"]] = relationship("Schedule", back_populates="class_", cascade="all, delete-orphan")
    seating: Mapped["Seating"] = relationship("Seating", back_populates="class_", uselist=False, cascade="all, delete-orphan")


class ClassMember(Base):
    __tablename__ = "class_members"
    __table_args__ = (
        UniqueConstraint("class_id", "user_id", name="uq_class_member"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    role: Mapped[str] = mapped_column(String(20))  # owner, teacher
    subject: Mapped[str | None] = mapped_column(String(50), nullable=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    class_: Mapped["Class"] = relationship("Class", back_populates="members")
    user: Mapped["User"] = relationship("User", back_populates="memberships")
