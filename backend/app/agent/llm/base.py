"""Unified LLM protocol: messages, images, tools, streaming chunks."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Literal, Optional

Role = Literal["system", "user", "assistant", "tool"]


@dataclass
class ImageContent:
    """Multimodal image input. Either a remote URL or base64-encoded data."""
    url: Optional[str] = None
    base64: Optional[str] = None
    mime_type: str = "image/png"

    def to_data_url(self) -> str:
        if self.url:
            return self.url
        return f"data:{self.mime_type};base64,{self.base64}"


@dataclass
class ToolCall:
    """A tool call requested by the model."""
    id: str
    name: str
    arguments: dict[str, Any] = field(default_factory=dict)


@dataclass
class ToolSpec:
    """OpenAI-style JSON-schema tool description."""
    name: str
    description: str
    parameters: dict[str, Any]  # JSON schema
    requires_confirmation: bool = False


@dataclass
class ChatMessage:
    role: Role
    content: str = ""
    images: list[ImageContent] = field(default_factory=list)
    tool_calls: list[ToolCall] = field(default_factory=list)
    tool_call_id: Optional[str] = None  # for role="tool"
    name: Optional[str] = None


@dataclass
class LLMStreamChunk:
    delta_text: str = ""
    tool_call_delta: Optional[ToolCall] = None
    finish_reason: Optional[str] = None


@dataclass
class LLMResponse:
    text: str = ""
    tool_calls: list[ToolCall] = field(default_factory=list)
    raw: Any = None


class BaseLLMProvider(ABC):
    """Abstract base for all LLM providers.

    Implementations must support multimodal inputs (text + images) and
    optional tool-calling. Streaming is the default; non-streaming wraps it.
    """

    name: str = "base"
    supports_vision: bool = True
    supports_tools: bool = True

    def __init__(
        self,
        api_key: str = "",
        base_url: Optional[str] = None,
        model: Optional[str] = None,
        **kwargs: Any,
    ) -> None:
        self.api_key = api_key
        self.base_url = base_url
        self.model = model
        self.extra: dict[str, Any] = kwargs

    @abstractmethod
    def stream(
        self,
        messages: list[ChatMessage],
        tools: Optional[list[ToolSpec]] = None,
        temperature: float = 0.7,
        **kwargs: Any,
    ) -> AsyncIterator[LLMStreamChunk]:
        """Yield streaming chunks. Implementations are async generators."""
        raise NotImplementedError

    async def chat(
        self,
        messages: list[ChatMessage],
        tools: Optional[list[ToolSpec]] = None,
        temperature: float = 0.7,
        **kwargs: Any,
    ) -> LLMResponse:
        """Non-streaming convenience wrapper that aggregates the stream."""
        text_parts: list[str] = []
        tool_calls: dict[str, ToolCall] = {}
        async for chunk in self.stream(messages, tools=tools, temperature=temperature, **kwargs):
            if chunk.delta_text:
                text_parts.append(chunk.delta_text)
            if chunk.tool_call_delta:
                tc = chunk.tool_call_delta
                existing = tool_calls.get(tc.id)
                if existing is None:
                    tool_calls[tc.id] = ToolCall(id=tc.id, name=tc.name, arguments=dict(tc.arguments))
                else:
                    if tc.name and not existing.name:
                        existing.name = tc.name
                    # Each chunk carries the cumulative parsed arguments;
                    # prefer fully-parsed args over partial blobs.
                    is_partial = set(tc.arguments.keys()) == {"_partial"}
                    if not is_partial:
                        existing.arguments = dict(tc.arguments)
                    elif not existing.arguments:
                        existing.arguments = dict(tc.arguments)
        return LLMResponse(text="".join(text_parts), tool_calls=list(tool_calls.values()))
