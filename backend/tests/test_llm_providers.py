"""Unit tests for the LLM provider abstraction layer.

We avoid making real network calls by patching `httpx.AsyncClient.stream` to
return a canned SSE/NDJSON stream.
"""
from __future__ import annotations

import json
from contextlib import asynccontextmanager
from typing import AsyncIterator

import pytest

from app.agent.llm import (
    ChatMessage,
    ImageContent,
    ToolSpec,
    available_providers,
    get_provider,
)
from app.agent.llm.openai_provider import OpenAIProvider
from app.agent.llm.anthropic_provider import AnthropicProvider
from app.agent.llm.ollama_provider import OllamaProvider


# Per-test asyncio markers below (file mixes sync + async tests)


class _FakeResponse:
    def __init__(self, lines: list[str]):
        self._lines = lines

    def raise_for_status(self) -> None:
        return None

    async def aiter_lines(self) -> AsyncIterator[str]:
        for ln in self._lines:
            yield ln


def _patch_stream(monkeypatch, lines: list[str]):
    """Patch httpx.AsyncClient.stream to yield a fake response."""
    import httpx

    @asynccontextmanager
    async def fake_stream(self, method, url, **kwargs):
        yield _FakeResponse(lines)

    monkeypatch.setattr(httpx.AsyncClient, "stream", fake_stream)


def test_available_providers():
    assert set(available_providers()) >= {"openai", "anthropic", "ollama"}


def test_get_provider_dispatch():
    assert isinstance(get_provider("openai", api_key="x"), OpenAIProvider)
    assert isinstance(get_provider("anthropic", api_key="x"), AnthropicProvider)
    assert isinstance(get_provider("ollama"), OllamaProvider)
    with pytest.raises(ValueError):
        get_provider("bogus")


@pytest.mark.asyncio
async def test_openai_stream_text(monkeypatch):
    sse = [
        f"data: {json.dumps({'choices': [{'delta': {'content': 'Hel'}}]})}",
        f"data: {json.dumps({'choices': [{'delta': {'content': 'lo'}}]})}",
        f"data: {json.dumps({'choices': [{'finish_reason': 'stop', 'delta': {}}]})}",
        "data: [DONE]",
    ]
    _patch_stream(monkeypatch, sse)
    p = OpenAIProvider(api_key="sk-test", model="gpt-test")
    resp = await p.chat([ChatMessage(role="user", content="hi")])
    assert resp.text == "Hello"


@pytest.mark.asyncio
async def test_openai_stream_tool_calls(monkeypatch):
    tc1 = {
        "choices": [
            {
                "delta": {
                    "tool_calls": [
                        {"index": 0, "id": "call_1", "function": {"name": "add_student", "arguments": '{"class'}}
                    ]
                }
            }
        ]
    }
    tc2 = {
        "choices": [
            {
                "delta": {
                    "tool_calls": [
                        {"index": 0, "function": {"arguments": '_id":1,"name":"A","gender":"male"}'}}
                    ]
                }
            }
        ]
    }
    sse = [f"data: {json.dumps(tc1)}", f"data: {json.dumps(tc2)}", "data: [DONE]"]
    _patch_stream(monkeypatch, sse)
    p = OpenAIProvider(api_key="sk-test", model="gpt-test")
    tools = [
        ToolSpec(name="add_student", description="x", parameters={"type": "object"}, requires_confirmation=True)
    ]
    resp = await p.chat([ChatMessage(role="user", content="add A")], tools=tools)
    assert len(resp.tool_calls) == 1
    tc = resp.tool_calls[0]
    assert tc.name == "add_student"
    assert tc.arguments == {"class_id": 1, "name": "A", "gender": "male"}


@pytest.mark.asyncio
async def test_openai_multimodal_message_shape():
    p = OpenAIProvider(api_key="sk")
    msg = ChatMessage(
        role="user",
        content="what is in this image?",
        images=[ImageContent(base64="AAA", mime_type="image/png")],
    )
    payload = OpenAIProvider._msg_to_dict(msg)
    assert payload["role"] == "user"
    assert isinstance(payload["content"], list)
    assert payload["content"][0]["type"] == "text"
    assert payload["content"][1]["type"] == "image_url"
    assert payload["content"][1]["image_url"]["url"].startswith("data:image/png;base64,")


@pytest.mark.asyncio
async def test_anthropic_stream_text(monkeypatch):
    events = [
        f"data: {json.dumps({'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': 'Hi '}})}",
        f"data: {json.dumps({'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': 'there'}})}",
        f"data: {json.dumps({'type': 'message_delta', 'delta': {'stop_reason': 'end_turn'}})}",
        f"data: {json.dumps({'type': 'message_stop'})}",
    ]
    _patch_stream(monkeypatch, events)
    p = AnthropicProvider(api_key="sk-anthr", model="claude-test")
    resp = await p.chat([ChatMessage(role="user", content="hi")])
    assert resp.text == "Hi there"


@pytest.mark.asyncio
async def test_anthropic_tool_use(monkeypatch):
    events = [
        f"data: {json.dumps({'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'tool_use', 'id': 'tu_1', 'name': 'add_student'}})}",
        f"data: {json.dumps({'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'input_json_delta', 'partial_json': '{\"class_id\":1,\"name\":\"A\",\"gender\":\"male\"}'}})}",
        f"data: {json.dumps({'type': 'message_stop'})}",
    ]
    _patch_stream(monkeypatch, events)
    p = AnthropicProvider(api_key="sk-anthr", model="claude-test")
    resp = await p.chat([ChatMessage(role="user", content="x")])
    assert len(resp.tool_calls) == 1
    assert resp.tool_calls[0].name == "add_student"
    assert resp.tool_calls[0].arguments["class_id"] == 1


@pytest.mark.asyncio
async def test_ollama_stream_ndjson(monkeypatch):
    lines = [
        json.dumps({"message": {"role": "assistant", "content": "Hello "}, "done": False}),
        json.dumps({"message": {"role": "assistant", "content": "world"}, "done": False}),
        json.dumps({"message": {"role": "assistant", "content": ""}, "done": True, "done_reason": "stop"}),
    ]
    _patch_stream(monkeypatch, lines)
    p = OllamaProvider(model="llama3.2")
    resp = await p.chat([ChatMessage(role="user", content="hi")])
    assert resp.text == "Hello world"
