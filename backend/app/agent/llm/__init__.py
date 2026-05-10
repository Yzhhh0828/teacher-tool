"""Unified LLM Provider abstraction.

Supports OpenAI-compatible, Anthropic, and Ollama APIs with a single
multi-modal `chat()` interface (text + images + tool-calls + streaming).
"""
from app.agent.llm.base import (
    BaseLLMProvider,
    ChatMessage,
    ImageContent,
    ToolCall,
    ToolSpec,
    LLMResponse,
    LLMStreamChunk,
)
from app.agent.llm.factory import (
    available_providers,
    current_override,
    get_provider,
    request_override,
)

__all__ = [
    "BaseLLMProvider",
    "ChatMessage",
    "ImageContent",
    "ToolCall",
    "ToolSpec",
    "LLMResponse",
    "LLMStreamChunk",
    "get_provider",
    "available_providers",
    "request_override",
    "current_override",
]
