import random
from typing import Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.student import Student
from app.models.exam import Exam, Grade
from app.models.seating import Seating
from app.models.class_ import ClassMember


class MCPTools:
    def __init__(self, db: AsyncSession, user_id: int):
        self.db = db
        self.user_id = user_id

    async def check_class_permission(self, class_id: int) -> ClassMember:
        """Check if user has access to class"""
        result = await self.db.execute(
            select(ClassMember).where(
                ClassMember.class_id == class_id,
                ClassMember.user_id == self.user_id,
            )
        )
        member = result.scalar_one_or_none()
        if not member:
            raise PermissionError("Not a member of this class")
        return member

    async def get_students(self, class_id: int) -> list[dict]:
        """Get all students in a class"""
        await self.check_class_permission(class_id)
        result = await self.db.execute(
            select(Student).where(Student.class_id == class_id).order_by(Student.id)
        )
        students = result.scalars().all()
        return [
            {
                "id": s.id,
                "name": s.name,
                "gender": s.gender,
                "phone": s.phone,
                "parent_phone": s.parent_phone,
            }
            for s in students
        ]

    async def add_student(
        self,
        class_id: int,
        name: str,
        gender: str,
        phone: Optional[str] = None,
        parent_phone: Optional[str] = None,
    ) -> dict:
        """Add a new student to a class"""
        member = await self.check_class_permission(class_id)
        if member.role != "owner":
            raise PermissionError("Only owner can add students")

        student = Student(
            class_id=class_id,
            name=name,
            gender=gender,
            phone=phone,
            parent_phone=parent_phone,
        )
        self.db.add(student)
        await self.db.commit()
        await self.db.refresh(student)
        return {"id": student.id, "name": student.name, "gender": student.gender}

    async def update_student(
        self,
        student_id: int,
        **fields,
    ) -> dict:
        """Update student information"""
        result = await self.db.execute(select(Student).where(Student.id == student_id))
        student = result.scalar_one_or_none()
        if not student:
            raise ValueError("Student not found")

        member = await self.check_class_permission(student.class_id)
        if member.role != "owner":
            raise PermissionError("Only owner can update students")

        for key, value in fields.items():
            if value is not None and hasattr(student, key):
                setattr(student, key, value)

        await self.db.commit()
        await self.db.refresh(student)
        return {"id": student.id, "name": student.name}

    async def delete_student(self, student_id: int) -> dict:
        """Delete a student"""
        result = await self.db.execute(select(Student).where(Student.id == student_id))
        student = result.scalar_one_or_none()
        if not student:
            raise ValueError("Student not found")

        member = await self.check_class_permission(student.class_id)
        if member.role != "owner":
            raise PermissionError("Only owner can delete students")

        name = student.name
        await self.db.delete(student)
        await self.db.commit()
        return {"success": True, "message": f"Student {name} deleted"}

    async def get_grades(self, exam_id: int) -> list[dict]:
        """Get all grades for an exam"""
        result = await self.db.execute(select(Exam).where(Exam.id == exam_id))
        exam = result.scalar_one_or_none()
        if not exam:
            raise ValueError("Exam not found")

        await self.check_class_permission(exam.class_id)

        result = await self.db.execute(
            select(Grade, Student)
            .join(Student, Grade.student_id == Student.id)
            .where(Grade.exam_id == exam_id)
        )
        grades = result.all()
        return [
            {
                "grade_id": g.id,
                "student_name": s.name,
                "subject": g.subject,
                "score": g.score,
            }
            for g, s in grades
        ]

    async def add_grade(
        self,
        exam_id: int,
        student_id: int,
        subject: str,
        score: float,
    ) -> dict:
        """Add or update a grade"""
        result = await self.db.execute(select(Exam).where(Exam.id == exam_id))
        exam = result.scalar_one_or_none()
        if not exam:
            raise ValueError("Exam not found")

        member = await self.check_class_permission(exam.class_id)
        if member.role == "teacher" and member.subject != subject:
            raise PermissionError("Cannot add grade for this subject")

        # Check student exists and belongs to the same class as the exam
        result = await self.db.execute(select(Student).where(Student.id == student_id))
        student = result.scalar_one_or_none()
        if not student:
            raise ValueError("Student not found")
        if student.class_id != exam.class_id:
            raise ValueError("Student does not belong to this class")

        # Check if grade already exists
        result = await self.db.execute(
            select(Grade).where(
                Grade.exam_id == exam_id,
                Grade.student_id == student_id,
                Grade.subject == subject,
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            existing.score = score
            grade = existing
        else:
            grade = Grade(
                exam_id=exam_id,
                student_id=student_id,
                subject=subject,
                score=score,
            )
            self.db.add(grade)

        await self.db.commit()
        await self.db.refresh(grade)
        return {"id": grade.id, "score": grade.score}

    async def get_seating(self, class_id: int) -> dict:
        """Get seating arrangement for a class"""
        await self.check_class_permission(class_id)

        result = await self.db.execute(select(Seating).where(Seating.class_id == class_id))
        seating = result.scalar_one_or_none()

        if not seating:
            return {"rows": 0, "cols": 0, "seats": []}

        return {
            "rows": seating.rows,
            "cols": seating.cols,
            "seats": seating.seats,
        }

    async def update_seating(self, class_id: int, seats: list) -> dict:
        """Update seating arrangement"""
        member = await self.check_class_permission(class_id)
        if member.role != "owner":
            raise PermissionError("Only owner can update seating")

        result = await self.db.execute(select(Seating).where(Seating.class_id == class_id))
        seating = result.scalar_one_or_none()

        if seating:
            seating.seats = seats
        else:
            seating = Seating(class_id=class_id, seats=seats)
            self.db.add(seating)

        await self.db.commit()
        return {"success": True}

    async def random_shuffle_seats(self, class_id: int) -> dict:
        """Randomly shuffle seats"""
        member = await self.check_class_permission(class_id)
        if member.role != "owner":
            raise PermissionError("Only owner can shuffle seats")

        # Get students
        result = await self.db.execute(
            select(Student).where(Student.class_id == class_id)
        )
        students = result.scalars().all()
        student_ids = [s.id for s in students]
        
        if not student_ids:
            return {"success": False, "message": "No students in this class"}

        random.shuffle(student_ids)

        # Get seating
        result = await self.db.execute(select(Seating).where(Seating.class_id == class_id))
        seating = result.scalar_one_or_none()

        if not seating:
            return {"success": False, "message": "No seating found"}

        # Create new arrangement
        rows, cols = seating.rows, seating.cols
        new_seats = []
        student_iter = iter(student_ids)
        for _ in range(rows):
            row = []
            for _ in range(cols):
                try:
                    row.append(next(student_iter))
                except StopIteration:
                    row.append(None)
            new_seats.append(row)

        seating.seats = new_seats
        await self.db.commit()

        return {"success": True, "seats": new_seats}
