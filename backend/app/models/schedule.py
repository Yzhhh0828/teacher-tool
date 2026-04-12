from sqlalchemy import String, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Schedule(Base):
    __tablename__ = "schedules"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    day_of_week: Mapped[int] = mapped_column(Integer)  # 0=Monday, 6=Sunday
    period: Mapped[int] = mapped_column(Integer)  # 1=第一节, 2=第二节...
    subject: Mapped[str] = mapped_column(String(50))
    teacher_name: Mapped[str] = mapped_column(String(100), nullable=True)
    classroom: Mapped[str] = mapped_column(String(100), nullable=True)

    class_: Mapped["Class"] = relationship("Class", back_populates="schedules")
