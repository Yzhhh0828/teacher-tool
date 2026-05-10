from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


# ─── Category ────────────────────────────────────────────────────────────────

class CategoryCreate(BaseModel):
    name: str
    icon: str = "star"
    score: float = 1.0
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    icon: Optional[str] = None
    score: Optional[float] = None
    sort_order: Optional[int] = None


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    class_id: int
    name: str
    icon: str
    score: float
    is_preset: bool
    sort_order: int


# ─── Record ──────────────────────────────────────────────────────────────────

class RecordCreate(BaseModel):
    student_ids: list[int]
    category_id: int
    note: Optional[str] = None


class RecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    class_id: int
    student_id: int
    category_id: int
    user_id: int
    score: float
    note: Optional[str] = None
    created_at: datetime
    category_name: Optional[str] = None
    student_name: Optional[str] = None


# ─── Stats ───────────────────────────────────────────────────────────────────

class StudentScore(BaseModel):
    student_id: int
    student_name: str
    total_score: float
    record_count: int
