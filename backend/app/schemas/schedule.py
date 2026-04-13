from pydantic import BaseModel, ConfigDict
from typing import Optional


class ScheduleBase(BaseModel):
    class_id: int
    day_of_week: int
    period: int
    subject: str
    teacher_name: Optional[str] = None
    classroom: Optional[str] = None


class ScheduleCreate(ScheduleBase):
    pass


class ScheduleUpdate(BaseModel):
    day_of_week: Optional[int] = None
    period: Optional[int] = None
    subject: Optional[str] = None
    teacher_name: Optional[str] = None
    classroom: Optional[str] = None


class ScheduleResponse(ScheduleBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
