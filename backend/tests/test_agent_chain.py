import sys
import types

import pytest

from app.agent.chain import AgentChain
from app.agent.session import ConversationSession


class DummyLLM:
    async def astream(self, _messages):
        if False:
            yield None


class FakeMCPTools:
    def __init__(self, _db, _user_id):
        pass

    async def random_shuffle_seats(self, **_params):
        return {"success": False, "message": "No seating found"}


@pytest.mark.asyncio
async def test_pending_action_with_missing_params_returns_clear_error(monkeypatch):
    monkeypatch.setattr("app.agent.chain.get_llm", lambda: DummyLLM())

    session = ConversationSession("session-1", 1)
    chain = AgentChain(session, db=object())
    session.set_pending_action(
        {
            "type": "add_student",
            "description": "添加学生",
            "params": {},
        }
    )

    result = await chain._execute_pending_action()

    assert result["action_executed"] is True
    assert "缺少必要参数" in result["content"]


@pytest.mark.asyncio
async def test_random_shuffle_seats_reports_failure_message(monkeypatch):
    monkeypatch.setattr("app.agent.chain.get_llm", lambda: DummyLLM())
    fake_module = types.SimpleNamespace(MCPTools=FakeMCPTools)
    monkeypatch.setitem(sys.modules, "app.mcp.tools", fake_module)

    session = ConversationSession("session-2", 1)
    chain = AgentChain(session, db=object())
    session.set_pending_action(
        {
            "type": "random_shuffle_seats",
            "description": "随机换座位",
            "params": {"class_id": 1},
        }
    )

    result = await chain._execute_pending_action()

    assert result["action_executed"] is True
    assert "No seating found" in result["content"]
