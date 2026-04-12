from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class ClassMemberBase(BaseModel):
    role: str
    subject: Optional[str] = None


class ClassMemberCreate(ClassMemberBase):
    user_id: int


class ClassMemberResponse(ClassMemberBase):
    id: int
    user_id: int
    class_id: int
    joined_at: datetime

    class Config:
        from_attributes = True


class ClassBase(BaseModel):
    name: str
    grade: str


class ClassCreate(ClassBase):
    pass


class ClassUpdate(BaseModel):
    name: Optional[str] = None
    grade: Optional[str] = None


class ClassResponse(ClassBase):
    id: int
    owner_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class ClassDetailResponse(ClassResponse):
    members: list[ClassMemberResponse] = []

    class Config:
        from_attributes = True


class InviteCodeResponse(BaseModel):
    invite_code: str
    expires_at: datetime


class JoinClassRequest(BaseModel):
    invite_code: str
    subject: str
