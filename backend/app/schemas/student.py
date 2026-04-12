from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class StudentBase(BaseModel):
    name: str
    gender: str
    phone: Optional[str] = None
    parent_phone: Optional[str] = None
    remarks: Optional[str] = None


class StudentCreate(StudentBase):
    class_id: int


class StudentUpdate(BaseModel):
    name: Optional[str] = None
    gender: Optional[str] = None
    phone: Optional[str] = None
    parent_phone: Optional[str] = None
    remarks: Optional[str] = None


class StudentResponse(StudentBase):
    id: int
    class_id: int
    created_at: datetime

    class Config:
        from_attributes = True
