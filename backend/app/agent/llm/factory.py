"""Provider factory — resolves LLM_PROVIDER setting + per-request overrides."""
from __future__ import annotations

from contextlib import contextmanager
from contextvars import ContextVar
from typing import Iterator, Optional

from app.config import settings
from app.agent.llm.base import BaseLLMProvider
from app.agent.llm.openai_provider import OpenAIProvider
from app.agent.llm.anthropic_provider import AnthropicProvider
from app.agent.llm.ollama_provider import OllamaProvider


_REGISTRY: dict[str, type[BaseLLMProvider]] = {
    "openai": OpenAIProvider,
    "anthropic": AnthropicProvider,
    "ollama": OllamaProvider,
}


# Request-scoped LLM override (provider/api_key/base_url/model). The chat
# endpoint and the direct tool-invocation endpoint set this so that any
# downstream code path — including vision tools that the LLM may invoke as
# part of an agentic loop — picks up the user's per-request credentials
# without having to thread `llm_override` through every function.
_current_override: ContextVar[Optional[dict]] = ContextVar(
    "llm_override", default=None
)


def available_providers() -> list[str]:
    return list(_REGISTRY.keys())


@contextmanager
def request_override(override: Optional[dict]) -> Iterator[None]:
    """Bind ``override`` for the duration of a request / agentic loop."""
    token = _current_override.set(override or None)
    try:
        yield
    finally:
        _current_override.reset(token)


def current_override() -> Optional[dict]:
    """Return the currently-bound LLM override, if any."""
    return _current_override.get()


def get_provider(
    provider: Optional[str] = None,
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    model: Optional[str] = None,
) -> BaseLLMProvider:
    """Resolve provider from explicit override, request-scoped override, or settings.

    Resolution order for each field:
        1. Explicit kwarg passed to this function.
        2. Request-scoped override set via `request_override(...)`.
        3. Process-wide ``Settings`` (``.env``).
    """
    ctx = _current_override.get() or {}
    provider = provider or ctx.get("provider")
    api_key = api_key or ctx.get("api_key")
    base_url = base_url or ctx.get("base_url")
    model = model or ctx.get("model")

    name = (provider or settings.LLM_PROVIDER or "openai").lower()
    cls = _REGISTRY.get(name)
    if cls is None:
        raise ValueError(f"Unknown LLM provider: {name}. Available: {available_providers()}")

    # Resolve credentials per provider with sensible env-driven defaults
    if name == "openai":
        api_key = api_key or settings.OPENAI_API_KEY
        base_url = base_url or settings.OPENAI_BASE_URL
        model = model or settings.OPENAI_MODEL
    elif name == "anthropic":
        api_key = api_key or settings.ANTHROPIC_API_KEY
        base_url = base_url or settings.ANTHROPIC_BASE_URL
        model = model or settings.ANTHROPIC_MODEL
    elif name == "ollama":
        base_url = base_url or settings.OLLAMA_BASE_URL
        model = model or settings.OLLAMA_MODEL

    return cls(api_key=api_key or "", base_url=base_url, model=model)
