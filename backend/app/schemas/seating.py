from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Any


class SeatingBase(BaseModel):
    rows: int = 6
    cols: int = 8
    seats: list[Any] = []


class SeatingUpdate(BaseModel):
    rows: Optional[int] = None
    cols: Optional[int] = None
    seats: Optional[list[Any]] = None


class SeatingResponse(SeatingBase):
    id: int
    class_id: int
    updated_at: datetime

    class Config:
        from_attributes = True


class ShuffleResponse(BaseModel):
    success: bool
    seats: list[Any]
