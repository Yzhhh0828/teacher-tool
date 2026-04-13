from pydantic import BaseModel, ConfigDict, Field
from datetime import datetime
from typing import Optional, Any


class SeatingBase(BaseModel):
    rows: int = 6
    cols: int = 8
    seats: list[Any] = Field(default_factory=list)


class SeatingUpdate(BaseModel):
    rows: Optional[int] = None
    cols: Optional[int] = None
    seats: Optional[list[Any]] = None


class SeatingResponse(SeatingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    class_id: int
    updated_at: datetime


class ShuffleResponse(BaseModel):
    success: bool
    seats: list[Any]
