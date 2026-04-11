# Phase 2: 核心 CRUD API

**目标:** 实现所有 CRUD 接口（班级、学生、成绩、座位、课表）

**Sub-plan for:** [主计划](./2026-04-12-teacher-tool-master-plan.md)

**Prerequisite:** Phase 1 完成

---

## 文件变更

### 新增文件
- `backend/app/models/student.py`
- `backend/app/models/exam.py`
- `backend/app/models/schedule.py`
- `backend/app/models/seating.py`
- `backend/app/api/class_.py`
- `backend/app/api/students.py`
- `backend/app/api/grades.py`
- `backend/app/api/seating.py`
- `backend/app/api/schedules.py`
- `backend/app/services/class_service.py`
- `backend/app/services/student_service.py`
- `backend/app/services/grade_service.py`

---

## Task 1: 完善数据模型

**Files:**
- Modify: `backend/app/models/__init__.py`
- Create: `backend/app/models/student.py`
- Create: `backend/app/models/exam.py`
- Create: `backend/app/models/schedule.py`
- Create: `backend/app/models/seating.py`

- [ ] **Step 1: Create app/models/student.py**

```python
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    name: Mapped[str] = mapped_column(String(100))
    gender: Mapped[str] = mapped_column(String(10))  # male, female
    phone: Mapped[str] = mapped_column(String(20), nullable=True)
    parent_phone: Mapped[str] = mapped_column(String(20), nullable=True)
    remarks: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    class_: Mapped["Class"] = relationship("Class", back_populates="students")
    grades: Mapped[list["Grade"]] = relationship("Grade", back_populates="student")
```

- [ ] **Step 2: Create app/models/exam.py**

```python
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Exam(Base):
    __tablename__ = "exams"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    name: Mapped[str] = mapped_column(String(200))
    date: Mapped[datetime] = mapped_column(DateTime)
    subjects: Mapped[list] = mapped_column(JSON, default=list)  # ["语文", "数学", "英语"]
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    class_: Mapped["Class"] = relationship("Class", back_populates="exams")
    grades: Mapped[list["Grade"]] = relationship("Grade", back_populates="exam")


class Grade(Base):
    __tablename__ = "grades"

    id: Mapped[int] = mapped_column(primary_key=True)
    exam_id: Mapped[int] = mapped_column(ForeignKey("exams.id"))
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id"))
    subject: Mapped[str] = mapped_column(String(50))
    score: Mapped[float] = mapped_column(default=0)
    remarks: Mapped[str] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    exam: Mapped["Exam"] = relationship("Exam", back_populates="grades")
    student: Mapped["Student"] = relationship("Student", back_populates="grades")
```

- [ ] **Step 3: Create app/models/schedule.py**

```python
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
```

- [ ] **Step 4: Create app/models/seating.py**

```python
from datetime import datetime
from sqlalchemy import String, Integer, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Seating(Base):
    __tablename__ = "seatings"

    id: Mapped[int] = mapped_column(primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"), unique=True)
    rows: Mapped[int] = mapped_column(Integer, default=6)
    cols: Mapped[int] = mapped_column(Integer, default=8)
    seats: Mapped[list] = mapped_column(JSON, default=list)  # 2D array of student IDs
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    class_: Mapped["Class"] = relationship("Class", back_populates="seating")
```

- [ ] **Step 5: Update app/models/__init__.py**

```python
from app.models.user import User
from app.models.class_ import Class, ClassMember
from app.models.student import Student
from app.models.exam import Exam, Grade
from app.models.schedule import Schedule
from app.models.seating import Seating

__all__ = [
    "User",
    "Class",
    "ClassMember",
    "Student",
    "Exam",
    "Grade",
    "Schedule",
    "Seating",
]
```

- [ ] **Step 6: Update Class and ClassMember models to add back_populates**

```python
# In class_.py, add:
students: Mapped[list["Student"]] = relationship("Student", back_populates="class_")
exams: Mapped[list["Exam"]] = relationship("Exam", back_populates="class_")
schedules: Mapped[list["Schedule"]] = relationship("Schedule", back_populates="class_")
seating: Mapped["Seating"] = relationship("Seating", back_populates="class_", uselist=False)
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add all data models (Student, Exam, Grade, Schedule, Seating)"
```

---

## Task 2: Pydantic Schemas

**Files:**
- Create: `backend/app/schemas/student.py`
- Create: `backend/app/schemas/exam.py`
- Create: `backend/app/schemas/class_.py`
- Create: `backend/app/schemas/seating.py`

- [ ] **Step 1: Create app/schemas/class_.py**

```python
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
```

- [ ] **Step 2: Create app/schemas/student.py**

```python
from pydantic import BaseModel
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
```

- [ ] **Step 3: Create app/schemas/exam.py**

```python
from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class ExamBase(BaseModel):
    name: str
    date: datetime
    subjects: list[str] = []


class ExamCreate(ExamBase):
    class_id: int


class ExamUpdate(BaseModel):
    name: Optional[str] = None
    date: Optional[datetime] = None
    subjects: Optional[list[str]] = None


class ExamResponse(ExamBase):
    id: int
    class_id: int
    created_at: datetime

    class Config:
        from_attributes = True


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
    id: int
    exam_id: int
    student_id: int

    class Config:
        from_attributes = True
```

- [ ] **Step 4: Create app/schemas/seating.py**

```python
from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class SeatingBase(BaseModel):
    rows: int = 6
    cols: int = 8
    seats: list = []  # 2D array


class SeatingUpdate(BaseModel):
    rows: Optional[int] = None
    cols: Optional[int] = None
    seats: Optional[list] = None


class SeatingResponse(SeatingBase):
    id: int
    class_id: int
    updated_at: datetime

    class Config:
        from_attributes = True


class ShuffleResponse(BaseModel):
    success: bool
    seats: list
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add Pydantic schemas"
```

---

## Task 3: 班级 API

**Files:**
- Create: `backend/app/api/class_.py`
- Modify: `backend/app/main.py` (include router)

- [ ] **Step 1: Create app/api/class_.py**

```python
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.class_ import Class, ClassMember
from app.schemas.class_ import (
    ClassCreate, ClassUpdate, ClassResponse, ClassDetailResponse,
    InviteCodeResponse, JoinClassRequest,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/classes", tags=["classes"])


def generate_invite_code() -> str:
    return secrets.token_urlsafe(8)


@router.post("", response_model=ClassResponse)
async def create_class(
    data: ClassCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    class_ = Class(name=data.name, grade=data.grade, owner_id=current_user.id)
    db.add(class_)
    await db.commit()
    await db.refresh(class_)

    # Add owner as a member
    member = ClassMember(class_id=class_.id, user_id=current_user.id, role="owner")
    db.add(member)
    await db.commit()

    return class_


@router.get("")
async def list_classes(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Get classes where user is owner or member
    result = await db.execute(
        select(Class)
        .join(ClassMember, Class.id == ClassMember.class_id)
        .where(ClassMember.user_id == current_user.id)
    )
    classes = result.scalars().all()
    return classes


@router.get("/{class_id}", response_model=ClassDetailResponse)
async def get_class(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check membership
    member_result = await db.execute(
        select(ClassMember)
        .where(ClassMember.class_id == class_id, ClassMember.user_id == current_user.id)
    )
    if not member_result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not a member of this class")

    result = await db.execute(
        select(Class)
        .options(selectinload(Class.members))
        .where(Class.id == class_id)
    )
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    return class_


@router.put("/{class_id}", response_model=ClassResponse)
async def update_class(
    class_id: int,
    data: ClassUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check if owner
    result = await db.execute(select(Class).where(Class.id == class_id, Class.owner_id == current_user.id))
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=403, detail="Only owner can update class")

    if data.name is not None:
        class_.name = data.name
    if data.grade is not None:
        class_.grade = data.grade

    await db.commit()
    await db.refresh(class_)
    return class_


@router.delete("/{class_id}")
async def delete_class(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check if owner
    result = await db.execute(select(Class).where(Class.id == class_id, Class.owner_id == current_user.id))
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=403, detail="Only owner can delete class")

    await db.delete(class_)
    await db.commit()
    return {"message": "Class deleted"}


@router.post("/{class_id}/invite_code", response_model=InviteCodeResponse)
async def create_invite_code(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check if owner
    result = await db.execute(select(Class).where(Class.id == class_id, Class.owner_id == current_user.id))
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=403, detail="Only owner can create invite code")

    invite_code = generate_invite_code()
    expires_at = datetime.utcnow() + timedelta(hours=24)

    # Store invite code in class (add field or use separate table)
    class_.invite_code = invite_code
    class_.invite_expires_at = expires_at

    await db.commit()
    return InviteCodeResponse(invite_code=invite_code, expires_at=expires_at)


@router.post("/join")
async def join_class(
    data: JoinClassRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Find class by invite code
    result = await db.execute(
        select(Class).where(
            Class.invite_code == data.invite_code,
            Class.invite_expires_at > datetime.utcnow(),
        )
    )
    class_ = result.scalar_one_or_none()

    if not class_:
        raise HTTPException(status_code=404, detail="Invalid or expired invite code")

    # Check if already a member
    member_result = await db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_.id,
            ClassMember.user_id == current_user.id,
        )
    )
    if member_result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Already a member")

    # Add as teacher
    member = ClassMember(
        class_id=class_.id,
        user_id=current_user.id,
        role="teacher",
        subject=data.subject,
    )
    db.add(member)
    await db.commit()

    return {"message": "Joined class successfully"}
```

- [ ] **Step 2: Update main.py to include class router**

```python
from app.api.class_ import router as class_router

app.include_router(class_router, prefix="/api/v1")
```

- [ ] **Step 3: Add invite_code and invite_expires_at fields to Class model**

Modify: `backend/app/models/class_.py`

```python
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
# add these fields:
invite_code: Mapped[str] = mapped_column(String(100), nullable=True)
invite_expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
```

- [ ] **Step 4: Run tests and commit**

```bash
git add -A && git commit -m "feat: add class API endpoints"
```

---

## Task 4: 学生 API

**Files:**
- Create: `backend/app/api/students.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Create app/api/students.py**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import Class, ClassMember
from app.models.student import Student
from app.schemas.student import StudentCreate, StudentUpdate, StudentResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/students", tags=["students"])


def check_class_permission(db: AsyncSession, class_id: int, user: User, require_owner: bool = False):
    """Check if user has permission to access class"""
    result = db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_id,
            ClassMember.user_id == user.id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this class")
    if require_owner and member.role != "owner":
        raise HTTPException(status_code=403, detail="Only owner can perform this action")
    return member


@router.post("", response_model=StudentResponse)
async def create_student(
    data: StudentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, data.class_id, current_user, require_owner=True)

    student = Student(**data.model_dump())
    db.add(student)
    await db.commit()
    await db.refresh(student)
    return student


@router.get("/class/{class_id}")
async def list_students(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, class_id, current_user)

    result = await db.execute(
        select(Student).where(Student.class_id == class_id).order_by(Student.id)
    )
    students = result.scalars().all()
    return students


@router.put("/{student_id}", response_model=StudentResponse)
async def update_student(
    student_id: int,
    data: StudentUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()

    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    check_class_permission(db, student.class_id, current_user, require_owner=True)

    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(student, key, value)

    await db.commit()
    await db.refresh(student)
    return student


@router.delete("/{student_id}")
async def delete_student(
    student_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()

    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    check_class_permission(db, student.class_id, current_user, require_owner=True)

    await db.delete(student)
    await db.commit()
    return {"message": "Student deleted"}
```

- [ ] **Step 2: Update main.py**

```python
from app.api.students import router as students_router

app.include_router(students_router, prefix="/api/v1")
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add student API endpoints"
```

---

## Task 5: 成绩 API

**Files:**
- Create: `backend/app/api/grades.py`

- [ ] **Step 1: Create app/api/grades.py**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import Class, ClassMember
from app.models.exam import Exam, Grade
from app.models.student import Student
from app.schemas.exam import ExamCreate, ExamUpdate, ExamResponse
from app.schemas.grade import GradeCreate, GradeUpdate, GradeResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/grades", tags=["grades"])


def check_class_permission(db, class_id, user, require_owner=False):
    result = db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_id,
            ClassMember.user_id == user.id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this class")
    if require_owner and member.role != "owner":
        raise HTTPException(status_code=403, detail="Only owner can perform this action")
    return member


# Exam endpoints
@router.post("/exams", response_model=ExamResponse)
async def create_exam(
    data: ExamCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, data.class_id, current_user, require_owner=True)

    exam = Exam(**data.model_dump())
    db.add(exam)
    await db.commit()
    await db.refresh(exam)
    return exam


@router.get("/exams/class/{class_id}")
async def list_exams(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, class_id, current_user)

    result = await db.execute(
        select(Exam).where(Exam.class_id == class_id).order_by(Exam.date.desc())
    )
    exams = result.scalars().all()
    return exams


# Grade endpoints
@router.post("", response_model=GradeResponse)
async def create_grade(
    data: GradeCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Get exam and check permission
    result = await db.execute(select(Exam).where(Exam.id == data.exam_id))
    exam = result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    check_class_permission(db, exam.class_id, current_user)

    # For teachers, check subject matches
    member_result = await db.execute(
        select(ClassMember).where(
            ClassMember.class_id == exam.class_id,
            ClassMember.user_id == current_user.id,
        )
    )
    member = member_result.scalar_one_or_none()

    if member.role == "teacher" and member.subject != data.subject:
        raise HTTPException(status_code=403, detail="Cannot add grade for this subject")

    grade = Grade(**data.model_dump())
    db.add(grade)
    await db.commit()
    await db.refresh(grade)
    return grade


@router.get("/exams/{exam_id}")
async def list_grades(
    exam_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Exam).where(Exam.id == exam_id))
    exam = result.scalar_one_or_none()

    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    check_class_permission(db, exam.class_id, current_user)

    result = await db.execute(
        select(Grade).where(Grade.exam_id == exam_id).order_by(Grade.student_id)
    )
    grades = result.scalars().all()
    return grades


@router.put("/{grade_id}", response_model=GradeResponse)
async def update_grade(
    grade_id: int,
    data: GradeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Grade).where(Grade.id == grade_id))
    grade = result.scalar_one_or_none()

    if not grade:
        raise HTTPException(status_code=404, detail="Grade not found")

    # Get exam for class permission check
    exam_result = await db.execute(select(Exam).where(Exam.id == grade.exam_id))
    exam = exam_result.scalar_one_or_none()

    check_class_permission(db, exam.class_id, current_user)

    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(grade, key, value)

    await db.commit()
    await db.refresh(grade)
    return grade


@router.delete("/{grade_id}")
async def delete_grade(
    grade_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Grade).where(Grade.id == grade_id))
    grade = result.scalar_one_or_none()

    if not grade:
        raise HTTPException(status_code=404, detail="Grade not found")

    exam_result = await db.execute(select(Exam).where(Exam.id == grade.exam_id))
    exam = exam_result.scalar_one_or_none()

    check_class_permission(db, exam.class_id, current_user, require_owner=True)

    await db.delete(grade)
    await db.commit()
    return {"message": "Grade deleted"}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add grade and exam API endpoints"
```

---

## Task 6: 座位 API

**Files:**
- Create: `backend/app/api/seating.py`

- [ ] **Step 1: Create app/api/seating.py**

```python
import random
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import ClassMember
from app.models.seating import Seating
from app.models.student import Student
from app.schemas.seating import SeatingUpdate, SeatingResponse, ShuffleResponse
from app.api.deps import get_current_user

router = APIRouter(prefix="/seating", tags=["seating"])


def check_class_permission(db, class_id, user, require_owner=False):
    result = db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_id,
            ClassMember.user_id == user.id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this class")
    if require_owner and member.role != "owner":
        raise HTTPException(status_code=403, detail="Only owner can perform this action")
    return member


def create_default_seats(rows: int, cols: int, student_ids: list) -> list:
    """Create a 2D seat array"""
    seats = []
    student_iter = iter(student_ids)
    for _ in range(rows):
        row = []
        for _ in range(cols):
            try:
                row.append(next(student_iter))
            except StopIteration:
                row.append(None)
        seats.append(row)
    return seats


@router.get("/class/{class_id}", response_model=SeatingResponse)
async def get_seating(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, class_id, current_user)

    result = await db.execute(select(Seating).where(Seating.class_id == class_id))
    seating = result.scalar_one_or_none()

    if not seating:
        # Create default seating
        student_result = await db.execute(
            select(Student).where(Student.class_id == class_id)
        )
        students = student_result.scalars().all()
        student_ids = [s.id for s in students]

        seats = create_default_seats(6, 8, student_ids)
        seating = Seating(class_id=class_id, rows=6, cols=8, seats=seats)
        db.add(seating)
        await db.commit()
        await db.refresh(seating)

    return seating


@router.put("/class/{class_id}", response_model=SeatingResponse)
async def update_seating(
    class_id: int,
    data: SeatingUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, class_id, current_user, require_owner=True)

    result = await db.execute(select(Seating).where(Seating.class_id == class_id))
    seating = result.scalar_one_or_none()

    if not seating:
        seating = Seating(class_id=class_id)
        db.add(seating)

    if data.rows is not None:
        seating.rows = data.rows
    if data.cols is not None:
        seating.cols = data.cols
    if data.seats is not None:
        seating.seats = data.seats

    await db.commit()
    await db.refresh(seating)
    return seating


@router.post("/class/{class_id}/shuffle", response_model=ShuffleResponse)
async def shuffle_seats(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, class_id, current_user, require_owner=True)

    result = await db.execute(select(Seating).where(Seating.class_id == class_id))
    seating = result.scalar_one_or_none()

    if not seating:
        raise HTTPException(status_code=404, detail="Seating not found")

    # Get all student IDs
    student_result = await db.execute(
        select(Student).where(Student.class_id == class_id)
    )
    students = student_result.scalars().all()
    student_ids = [s.id for s in students]

    # Shuffle
    random.shuffle(student_ids)

    # Create new seat arrangement
    seats = create_default_seats(seating.rows, seating.cols, student_ids)
    seating.seats = seats

    await db.commit()
    await db.refresh(seating)

    return ShuffleResponse(success=True, seats=seats)
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add seating API endpoints"
```

---

## Task 7: 课表 API

**Files:**
- Create: `backend/app/api/schedules.py`

- [ ] **Step 1: Create app/api/schedules.py**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.user import User
from app.models.class_ import ClassMember
from app.models.schedule import Schedule
from app.api.deps import get_current_user

router = APIRouter(prefix="/schedules", tags=["schedules"])


def check_class_permission(db, class_id, user):
    result = db.execute(
        select(ClassMember).where(
            ClassMember.class_id == class_id,
            ClassMember.user_id == user.id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this class")
    return member


@router.post("")
async def create_schedule(
    data: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    class_id = data.get("class_id")
    check_class_permission(db, class_id, current_user)

    schedule = Schedule(**data)
    db.add(schedule)
    await db.commit()
    await db.refresh(schedule)
    return schedule


@router.get("/class/{class_id}")
async def list_schedules(
    class_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_class_permission(db, class_id, current_user)

    result = await db.execute(
        select(Schedule)
        .where(Schedule.class_id == class_id)
        .order_by(Schedule.day_of_week, Schedule.period)
    )
    schedules = result.scalars().all()
    return schedules


@router.delete("/{schedule_id}")
async def delete_schedule(
    schedule_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()

    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    check_class_permission(db, schedule.class_id, current_user)

    await db.delete(schedule)
    await db.commit()
    return {"message": "Schedule deleted"}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add schedule API endpoints"
```

---

## 自检清单

- [ ] 学生 CRUD API 可用
- [ ] 考试 CRUD API 可用
- [ ] 成绩 CRUD API 可用
- [ ] 座位 CRUD + 随机换座位 API 可用
- [ ] 课表 CRUD API 可用
- [ ] 权限检查正确（owner vs teacher）
- [ ] 所有测试通过
