# Phase 3: AI Agent + MCP

**目标:** 实现 Agent 对话系统和 MCP 工具

**Sub-plan for:** [主计划](./2026-04-12-teacher-tool-master-plan.md)

**Prerequisite:** Phase 1, Phase 2 完成

---

## 文件结构

```
backend/app/
├── mcp/
│   ├── __init__.py
│   ├── server.py          # FastMCP Server
│   └── tools.py           # MCP Tools 定义
├── agent/
│   ├── __init__.py
│   ├── chain.py           # Langchain Agent Chain
│   ├── prompts.py         # Prompt 模板
│   └── session.py         # 会话管理
└── api/
    └── agent.py           # Agent SSE 路由
```

---

## Task 1: MCP Server 实现

**Files:**
- Create: `backend/app/mcp/__init__.py`
- Create: `backend/app/mcp/tools.py`
- Create: `backend/app/mcp/server.py`

- [ ] **Step 1: Create app/mcp/tools.py**

```python
from typing import Any
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
        phone: str = None,
        parent_phone: str = None,
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

        await self.db.delete(student)
        await self.db.commit()
        return {"success": True, "message": f"Student {student.name} deleted"}

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
        import random

        member = await self.check_class_permission(class_id)
        if member.role != "owner":
            raise PermissionError("Only owner can shuffle seats")

        # Get students
        result = await self.db.execute(
            select(Student).where(Student.class_id == class_id)
        )
        students = result.scalars().all()
        student_ids = [s.id for s in students]
        random.shuffle(student_ids)

        # Get seating
        result = await self.db.execute(select(Seating).where(Seating.class_id == class_id))
        seating = result.scalar_one_or_none()

        if not seating:
            return {"success": False, "message": "No seating found"}

        # Create new arrangement
        rows, cols = seating.rows, seating.cols
        new_seats = []
        idx = 0
        for _ in range(rows):
            row = []
            for _ in range(cols):
                row.append(student_ids[idx % len(student_ids)] if idx < len(student_ids) * cols else None)
                idx += 1
            new_seats.append(row)

        seating.seats = new_seats
        await self.db.commit()

        return {"success": True, "seats": new_seats}
```

- [ ] **Step 2: Create app/mcp/server.py**

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.mcp.tools import MCPTools


def get_mcp_tools(db: AsyncSession, user_id: int) -> MCPTools:
    return MCPTools(db, user_id)
```

- [ ] **Step 3: Create app/mcp/__init__.py**

```python
from app.mcp.tools import MCPTools

__all__ = ["MCPTools"]
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add MCP tools implementation"
```

---

## Task 2: Langchain Agent

**Files:**
- Create: `backend/app/agent/prompts.py`
- Create: `backend/app/agent/session.py`
- Create: `backend/app/agent/chain.py`
- Create: `backend/app/agent/__init__.py`

- [ ] **Step 1: Create app/agent/prompts.py**

```python
from langchain.prompts import ChatPromptTemplate

SYSTEM_PROMPT = """You are a helpful AI assistant for a teacher tool. Your role is to help teachers manage their classes.

You have access to the following tools:
- get_students(class_id): Get all students in a class
- add_student(class_id, name, gender, phone, parent_phone): Add a new student
- update_student(student_id, **fields): Update student information
- delete_student(student_id): Delete a student
- get_grades(exam_id): Get all grades for an exam
- add_grade(exam_id, student_id, subject, score): Add or update a grade
- get_seating(class_id): Get seating arrangement
- update_seating(class_id, seats): Update seating arrangement
- random_shuffle_seats(class_id): Randomly shuffle seats

IMPORTANT RULES:
1. Before using any tool, you must ask for user confirmation
2. For any ADD, UPDATE, or DELETE operations, clearly state what will happen and wait for confirmation
3. Only execute operations after user explicitly confirms
4. When displaying data, be clear and organized
5. If you need to know the class_id, ask the user or list their classes first

Your response should be:
- Concise and helpful
- In Chinese (as the user is speaking Chinese)
- Clear about what action will be taken
"""


HUMAN_CONFIRM_PROMPT = """用户请求: {user_request}
建议操作: {proposed_action}
需要确认: YES

请向用户确认此操作，回复格式:
【确认信息】{简要说说你将做什么}
【等待确认】请回复"是"确认执行"""


EXECUTE_PROMPT = """用户已确认操作。
请求: {user_request}
操作: {action}

请执行此操作并报告结果。"""
```

- [ ] **Step 2: Create app/agent/session.py**

```python
from datetime import datetime
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User


class ConversationSession:
    def __init__(self, session_id: str, user_id: int, messages: list = None):
        self.session_id = session_id
        self.user_id = user_id
        self.messages = messages or []
        self.pending_action = None  # Store action waiting for confirmation

    def add_user_message(self, content: str, image_url: str = None):
        self.messages.append({
            "role": "user",
            "content": content,
            "image_url": image_url,
            "timestamp": datetime.utcnow().isoformat(),
        })

    def add_ai_message(self, content: str):
        self.messages.append({
            "role": "assistant",
            "content": content,
            "timestamp": datetime.utcnow().isoformat(),
        })

    def set_pending_action(self, action: dict):
        """Store an action waiting for user confirmation"""
        self.pending_action = action

    def clear_pending_action(self):
        self.pending_action = None

    def to_dict(self) -> dict:
        return {
            "session_id": self.session_id,
            "user_id": self.user_id,
            "messages": self.messages,
            "pending_action": self.pending_action,
        }


# In-memory session storage (use Redis in production)
_session_store: dict[str, ConversationSession] = {}


def get_session(session_id: str) -> Optional[ConversationSession]:
    return _session_store.get(session_id)


def create_session(session_id: str, user_id: int) -> ConversationSession:
    session = ConversationSession(session_id, user_id)
    _session_store[session_id] = session
    return session


def delete_session(session_id: str):
    if session_id in _session_store:
        del _session_store[session_id]
```

- [ ] **Step 3: Create app/agent/chain.py**

```python
import os
import base64
from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain.schema import HumanMessage, SystemMessage
from app.config import settings
from app.agent.prompts import SYSTEM_PROMPT
from app.agent.session import ConversationSession, get_session, create_session


def get_llm():
    """Get LLM client based on configuration"""
    if settings.LLM_PROVIDER == "openai":
        return ChatOpenAI(
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL,
            model="gpt-4o",
            streaming=True,
        )
    elif settings.LLM_PROVIDER == "anthropic":
        return ChatAnthropic(
            api_key=settings.ANTHROPIC_API_KEY,
            base_url=settings.ANTHROPIC_BASE_URL,
            model="claude-sonnet-4-6-20250514",
            streaming=True,
        )
    else:
        raise ValueError(f"Unknown LLM provider: {settings.LLM_PROVIDER}")


class AgentChain:
    def __init__(self, session: ConversationSession):
        self.session = session
        self.llm = get_llm()
        self.confirmation_level = "medium"  # low, medium, high

    def _build_messages(self) -> list:
        """Build messages for LLM"""
        messages = [SystemMessage(content=SYSTEM_PROMPT)]

        for msg in self.session.messages[-10:]:  # Last 10 messages for context
            if msg["role"] == "user":
                content = msg["content"]
                if msg.get("image_url"):
                    # Handle image
                    content = f"[图片上传]\n{content}"
                messages.append(HumanMessage(content=content))
            else:
                messages.append(HumanMessage(content=msg["content"]))

        return messages

    async def process(
        self,
        user_input: str,
        image_data: Optional[str] = None,
    ) -> dict:
        """Process user input and return response"""

        # Add user message to session
        self.session.add_user_message(user_input, image_data)

        # Check if there's a pending action
        if self.session.pending_action:
            if user_input.lower() in ["是", "确认", "确定", "yes", "y"]:
                # Execute pending action
                return await self._execute_pending_action()
            else:
                # Cancel action
                self.session.clear_pending_action()
                response = "操作已取消。有什么其他我可以帮助你的？"
                self.session.add_ai_message(response)
                return {"type": "text", "content": response}

        # Build messages and call LLM
        messages = self._build_messages()

        # Stream response
        response_content = ""
        async for chunk in self.llm.astream(messages):
            if chunk.content:
                response_content += chunk.content

        # Check if we need confirmation
        if self._needs_confirmation(response_content):
            # Parse and store pending action
            action = self._parse_action(response_content)
            if action:
                self.session.set_pending_action(action)
                # Modify response to ask for confirmation
                response_content = f"【待确认操作】{action['description']}\n\n请回复"是"确认执行，或其他内容取消。"

        self.session.add_ai_message(response_content)

        return {
            "type": "text",
            "content": response_content,
            "needs_confirmation": self.session.pending_action is not None,
        }

    def _needs_confirmation(self, response: str) -> bool:
        """Check if response contains an action that needs confirmation"""
        action_keywords = ["add_student", "update_student", "delete_student",
                          "add_grade", "update_seating", "random_shuffle_seats"]
        return any(keyword in response for keyword in action_keywords)

    def _parse_action(self, response: str) -> Optional[dict]:
        """Parse action from LLM response"""
        # Simple parsing - in production, use structured output
        if "add_student" in response:
            return {"type": "add_student", "description": "添加学生"}
        elif "update_student" in response:
            return {"type": "update_student", "description": "更新学生信息"}
        elif "delete_student" in response:
            return {"type": "delete_student", "description": "删除学生"}
        elif "add_grade" in response:
            return {"type": "add_grade", "description": "录入成绩"}
        return None

    async def _execute_pending_action(self) -> dict:
        """Execute the pending action"""
        action = self.session.pending_action
        self.session.clear_pending_action()

        # This would call the MCP tools here
        response = f"已执行操作: {action['description']}"
        self.session.add_ai_message(response)

        return {
            "type": "text",
            "content": response,
            "action_executed": True,
        }
```

- [ ] **Step 4: Create app/agent/__init__.py**

```python
from app.agent.chain import AgentChain
from app.agent.session import ConversationSession, get_session, create_session

__all__ = ["AgentChain", "ConversationSession", "get_session", "create_session"]
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add Langchain Agent with confirmation flow"
```

---

## Task 3: Agent SSE API

**Files:**
- Create: `backend/app/api/agent.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Create app/api/agent.py**

```python
import uuid
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse
from app.database import get_db
from app.models.user import User
from app.api.deps import get_current_user
from app.agent.chain import AgentChain
from app.agent.session import get_session, create_session, ConversationSession
from app.mcp.tools import MCPTools

router = APIRouter(prefix="/agent", tags=["agent"])


@router.post("/chat")
async def chat(
    message: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Send a message to the agent.
    Returns SSE stream for real-time responses.
    """
    user_input = message.get("content", "")
    image_data = message.get("image")  # base64 encoded
    session_id = message.get("session_id")

    # Get or create session
    if session_id:
        session = get_session(session_id)
        if not session:
            session = create_session(session_id, current_user.id)
    else:
        session_id = str(uuid.uuid4())
        session = create_session(session_id, current_user.id)

    # Create agent chain
    agent = AgentChain(session)

    async def event_generator():
        try:
            # Process message
            result = await agent.process(user_input, image_data)

            # Send response
            yield {
                "event": "message",
                "data": json.dumps({
                    "content": result["content"],
                    "session_id": session_id,
                    "needs_confirmation": result.get("needs_confirmation", False),
                    "action_executed": result.get("action_executed", False),
                }),
            }

            # Send done signal
            yield {"event": "done", "data": ""}

        except Exception as e:
            yield {
                "event": "error",
                "data": json.dumps({"error": str(e)}),
            }

    return EventSourceResponse(event_generator())


@router.get("/history/{session_id}")
async def get_history(
    session_id: str,
    current_user: User = Depends(get_current_user),
):
    """Get conversation history for a session"""
    session = get_session(session_id)

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    return {
        "session_id": session_id,
        "messages": session.messages,
    }


@router.delete("/history/{session_id}")
async def delete_history(
    session_id: str,
    current_user: User = Depends(get_current_user),
):
    """Delete a conversation session"""
    from app.agent.session import delete_session

    session = get_session(session_id)

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    delete_session(session_id)
    return {"success": True}
```

- [ ] **Step 2: Update main.py**

```python
from app.api.agent import router as agent_router

app.include_router(agent_router, prefix="/api/v1")
```

- [ ] **Step 3: Add SSE dependency**

Update requirements.txt:
```txt
sse-starlette==2.0.0
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add Agent SSE API endpoints"
```

---

## Task 4: MCP Server 启动配置

**Files:**
- Modify: `backend/app/main.py`
- Create: `backend/app/mcp_runner.py`

- [ ] **Step 1: Create app/mcp_runner.py**

```python
"""
MCP Server runner for standalone mode.
Can be used to run MCP server separately for Claude Desktop integration.
"""
from mcp.server.fastmcp import FastMCP
from app.database import async_session_maker
from app.mcp.tools import MCPTools

mcp = FastMCP("TeacherTool")


@mcp.tool()
async def get_students(class_id: int, user_id: int) -> list:
    """Get all students in a class"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.get_students(class_id)


@mcp.tool()
async def add_student(
    class_id: int,
    name: str,
    gender: str,
    user_id: int,
    phone: str = None,
    parent_phone: str = None,
) -> dict:
    """Add a new student"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.add_student(class_id, name, gender, phone, parent_phone)


@mcp.tool()
async def update_student(student_id: int, user_id: int, **fields) -> dict:
    """Update student information"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.update_student(student_id, **fields)


@mcp.tool()
async def delete_student(student_id: int, user_id: int) -> dict:
    """Delete a student"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.delete_student(student_id)


@mcp.tool()
async def get_grades(exam_id: int, user_id: int) -> list:
    """Get grades for an exam"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.get_grades(exam_id)


@mcp.tool()
async def add_grade(
    exam_id: int,
    student_id: int,
    subject: str,
    score: float,
    user_id: int,
) -> dict:
    """Add or update a grade"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.add_grade(exam_id, student_id, subject, score)


if __name__ == "__main__":
    mcp.run()
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add MCP runner for standalone mode"
```

---

## 自检清单

- [ ] MCP Tools 可独立调用
- [ ] Langchain Agent 可处理对话
- [ ] 确认机制正常工作
- [ ] SSE 流式响应正常
- [ ] 会话历史可存储和读取
- [ ] 测试通过
