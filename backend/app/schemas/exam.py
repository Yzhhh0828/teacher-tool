from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional


class ExamBase(BaseModel):
    name: str
    date: datetime


class ExamCreate(ExamBase):
    class_id: int


class ExamUpdate(BaseModel):
    name: Optional[str] = None
    date: Optional[datetime] = None


class ExamResponse(ExamBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    class_id: int
    created_at: datetime


class GradeBase(BaseModel):
    subject: str
    score: float
    remarks: Optional[str] = None


class GradeCreate(GradeBase):
    exam_id: int
    student_id: int


class GradeUpdate(BaseModel):
    score: Optional[float] = None
    remarks: Optional[str] = None


class GradeResponse(GradeBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    exam_id: int
    student_id: int
    created_at: datetime
