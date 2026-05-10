"""Agent tools registry — JSON-schema'd functions exposed to the LLM.

Each tool returns a JSON-serialisable dict. Write tools have
`requires_confirmation=True` so the agent emits a `pending_action` and the
frontend must call `/agent/confirm` before the tool actually runs.
"""
from app.agent.tools.registry import (
    ToolRegistry,
    registry,
    Tool,
)
from app.agent.tools import student_tools  # noqa: F401  (registers tools)
from app.agent.tools import grade_tools    # noqa: F401
from app.agent.tools import seating_tools  # noqa: F401
from app.agent.tools import analytics_tools  # noqa: F401
from app.agent.tools import classroom_tools  # noqa: F401
from app.agent.tools import vision_import   # noqa: F401

__all__ = ["ToolRegistry", "registry", "Tool"]
