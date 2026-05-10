"""Native tool-calling flow inside AgentChain.

We stub the LLM with a tiny scripted provider that emits canned tool_calls
on each round. This covers:

* Read-only tool execution + automatic continuation.
* Write tool buffering, confirmation flow, and execution on "yes".
"""
from __future__ import annotations

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.agent.chain import AgentChain
from app.agent.llm.base import BaseLLMProvider, LLMStreamChunk, ToolCall
from app.agent.session import ConversationSession
from app.database import Base
from app.models.class_ import Class, ClassMember
from app.models.user import User


pytestmark = pytest.mark.asyncio


class ScriptedLLM(BaseLLMProvider):
    """Yields a queued list of stream-chunks per call."""

    def __init__(self, scripts):
        super().__init__(api_key="x")
        self._scripts = list(scripts)

    async def stream(self, messages, tools=None, temperature=0.7, **kwargs):
        if not self._scripts:
            # Default to "I'm done" once the script is exhausted.
            yield LLMStreamChunk(delta_text="ok")
            return
        chunks = self._scripts.pop(0)
        for c in chunks:
            yield c


@pytest.fixture
async def seeded():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        user = User(phone="13900200001", password_hash="x")
        session.add(user)
        await session.flush()
        cls = Class(name="C", grade="G", owner_id=user.id)
        session.add(cls)
        await session.flush()
        session.add(ClassMember(class_id=cls.id, user_id=user.id, role="owner"))
        await session.commit()
        yield session, user.id, cls.id
    await engine.dispose()


async def test_read_tool_auto_executes_then_terminates(seeded, monkeypatch):
    session, user_id, class_id = seeded

    # Round 1 — model wants to list students.
    round1 = [
        LLMStreamChunk(
            tool_call_delta=ToolCall(
                id="c1",
                name="list_students",
                arguments={"class_id": class_id},
            )
        )
    ]
    # Round 2 — model gives a final answer.
    round2 = [LLMStreamChunk(delta_text="Class has 0 students.")]
    llm = ScriptedLLM([round1, round2])

    monkeypatch.setattr("app.agent.chain.get_llm", lambda *a, **kw: llm)

    convo = ConversationSession("s-read", user_id)
    chain = AgentChain(convo, db=session)
    result = await chain.process("List all students.")

    assert result["action_executed"] is False
    assert "students" in result["content"].lower()
    traces = result["tool_traces"]
    assert traces and traces[0]["name"] == "list_students" and traces[0]["ok"]


async def test_write_tool_pending_then_confirmed(seeded, monkeypatch):
    session, user_id, class_id = seeded

    # Round 1 — model wants to bulk-create two students.
    round1 = [
        LLMStreamChunk(
            tool_call_delta=ToolCall(
                id="c1",
                name="bulk_create_students",
                arguments={
                    "class_id": class_id,
                    "items": [
                        {"name": "甲", "gender": "male"},
                        {"name": "乙", "gender": "female"},
                    ],
                },
            )
        )
    ]
    # After confirmation, summary round.
    summary = [LLMStreamChunk(delta_text="已添加 2 名学生。")]
    llm = ScriptedLLM([round1, summary])

    monkeypatch.setattr("app.agent.chain.get_llm", lambda *a, **kw: llm)

    convo = ConversationSession("s-write", user_id)
    chain = AgentChain(convo, db=session)

    pending = await chain.process("Add 甲 and 乙.")
    assert pending["needs_confirmation"] is True
    assert pending["action_executed"] is False
    assert "bulk_create_students" in pending["content"]
    assert convo.pending_action and convo.pending_action["kind"] == "tool_calls"

    # Confirm it.
    final = await chain.process("是")
    assert final["action_executed"] is True
    assert final["tool_traces"][0]["ok"] is True
    assert final["tool_traces"][0]["result"]["created"] == 2


async def test_write_tool_cancelled_with_no(seeded, monkeypatch):
    session, user_id, class_id = seeded

    round1 = [
        LLMStreamChunk(
            tool_call_delta=ToolCall(
                id="c1",
                name="add_student",
                arguments={"class_id": class_id, "name": "丙", "gender": "male"},
            )
        )
    ]
    llm = ScriptedLLM([round1])
    monkeypatch.setattr("app.agent.chain.get_llm", lambda *a, **kw: llm)

    convo = ConversationSession("s-cancel", user_id)
    chain = AgentChain(convo, db=session)

    pending = await chain.process("Add 丙.")
    assert pending["needs_confirmation"] is True

    cancel = await chain.process("不要")
    assert "取消" in cancel["content"]
    assert convo.pending_action is None
