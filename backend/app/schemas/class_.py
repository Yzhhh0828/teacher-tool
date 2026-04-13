from pydantic import BaseModel, ConfigDict, Field
from datetime import datetime
from typing import Optional


class ClassMemberBase(BaseModel):
    role: str
    subject: Optional[str] = None


class ClassMemberCreate(ClassMemberBase):
    user_id: int


class ClassMemberResponse(ClassMemberBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    class_id: int
    joined_at: datetime


class ClassBase(BaseModel):
    name: str
    grade: str


class ClassCreate(ClassBase):
    pass


class ClassUpdate(BaseModel):
    name: Optional[str] = None
    grade: Optional[str] = None


class ClassResponse(ClassBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    owner_id: int
    created_at: datetime


class ClassDetailResponse(ClassResponse):
    model_config = ConfigDict(from_attributes=True)
    members: list[ClassMemberResponse] = Field(default_factory=list)


class InviteCodeResponse(BaseModel):
    invite_code: str
    expires_at: datetime


class JoinClassRequest(BaseModel):
    invite_code: str
    subject: str
