"""Lightweight tool registry decoupled from any specific framework."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.llm.base import ToolSpec


ToolFn = Callable[..., Awaitable[Any]]


@dataclass
class Tool:
    name: str
    description: str
    parameters: dict[str, Any]
    handler: ToolFn
    requires_confirmation: bool = False
    category: str = "misc"

    def to_spec(self) -> ToolSpec:
        return ToolSpec(
            name=self.name,
            description=self.description,
            parameters=self.parameters,
            requires_confirmation=self.requires_confirmation,
        )


class ToolRegistry:
    def __init__(self) -> None:
        self._tools: dict[str, Tool] = {}

    def register(self, tool: Tool) -> Tool:
        self._tools[tool.name] = tool
        return tool

    def tool(
        self,
        *,
        name: str,
        description: str,
        parameters: dict[str, Any],
        requires_confirmation: bool = False,
        category: str = "misc",
    ) -> Callable[[ToolFn], ToolFn]:
        def decorator(fn: ToolFn) -> ToolFn:
            self.register(
                Tool(
                    name=name,
                    description=description,
                    parameters=parameters,
                    handler=fn,
                    requires_confirmation=requires_confirmation,
                    category=category,
                )
            )
            return fn
        return decorator

    def get(self, name: str) -> Optional[Tool]:
        return self._tools.get(name)

    def specs(self, category: Optional[str] = None) -> list[ToolSpec]:
        return [
            t.to_spec()
            for t in self._tools.values()
            if category is None or t.category == category
        ]

    def all(self) -> list[Tool]:
        return list(self._tools.values())

    async def invoke(self, name: str, *, db: AsyncSession, user_id: int, **kwargs: Any) -> Any:
        tool = self.get(name)
        if tool is None:
            raise ValueError(f"Unknown tool: {name}")
        return await tool.handler(db=db, user_id=user_id, **kwargs)


registry = ToolRegistry()
