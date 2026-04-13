from pydantic import BaseModel, ConfigDict
from datetime import datetime


class UserBase(BaseModel):
    phone: str


class UserCreate(UserBase):
    password: str


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
