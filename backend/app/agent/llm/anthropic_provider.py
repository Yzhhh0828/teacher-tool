"""Anthropic Claude Messages API provider (vision + tool-use)."""
from __future__ import annotations

import json
from typing import Any, AsyncIterator, Optional

import httpx

from app.agent.llm.base import (
    BaseLLMProvider,
    ChatMessage,
    LLMStreamChunk,
    ToolCall,
    ToolSpec,
)


class AnthropicProvider(BaseLLMProvider):
    name = "anthropic"
    supports_vision = True
    supports_tools = True

    DEFAULT_MODEL = "claude-3-5-sonnet-latest"
    DEFAULT_BASE_URL = "https://api.anthropic.com"
    API_VERSION = "2023-06-01"

    def __init__(self, api_key: str = "", base_url: Optional[str] = None, model: Optional[str] = None, **kwargs: Any) -> None:
        super().__init__(api_key=api_key, base_url=base_url or self.DEFAULT_BASE_URL, model=model or self.DEFAULT_MODEL, **kwargs)

    @staticmethod
    def _split_system(messages: list[ChatMessage]) -> tuple[str, list[ChatMessage]]:
        system_parts: list[str] = []
        rest: list[ChatMessage] = []
        for m in messages:
            if m.role == "system":
                system_parts.append(m.content)
            else:
                rest.append(m)
        return "\n\n".join(system_parts), rest

    @staticmethod
    def _msg_to_dict(msg: ChatMessage) -> dict[str, Any]:
        if msg.role == "tool":
            return {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": msg.tool_call_id or "",
                        "content": msg.content,
                    }
                ],
            }

        if msg.role == "assistant" and msg.tool_calls:
            blocks: list[dict[str, Any]] = []
            if msg.content:
                blocks.append({"type": "text", "text": msg.content})
            for tc in msg.tool_calls:
                blocks.append({"type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.arguments})
            return {"role": "assistant", "content": blocks}

        # user / assistant text+image
        blocks: list[dict[str, Any]] = []
        if msg.content:
            blocks.append({"type": "text", "text": msg.content})
        for img in msg.images:
            if img.base64:
                blocks.append({
                    "type": "image",
                    "source": {"type": "base64", "media_type": img.mime_type, "data": img.base64},
                })
            elif img.url:
                blocks.append({"type": "image", "source": {"type": "url", "url": img.url}})
        if not blocks:
            blocks = [{"type": "text", "text": ""}]
        return {"role": msg.role, "content": blocks}

    @staticmethod
    def _tools_to_payload(tools: Optional[list[ToolSpec]]) -> Optional[list[dict[str, Any]]]:
        if not tools:
            return None
        return [
            {"name": t.name, "description": t.description, "input_schema": t.parameters}
            for t in tools
        ]

    async def stream(
        self,
        messages: list[ChatMessage],
        tools: Optional[list[ToolSpec]] = None,
        temperature: float = 0.7,
        **kwargs: Any,
    ) -> AsyncIterator[LLMStreamChunk]:
        system_prompt, rest = self._split_system(messages)
        payload: dict[str, Any] = {
            "model": kwargs.get("model") or self.model,
            "messages": [self._msg_to_dict(m) for m in rest],
            "max_tokens": kwargs.get("max_tokens", 4096),
            "temperature": temperature,
            "stream": True,
        }
        if system_prompt:
            payload["system"] = system_prompt
        tp = self._tools_to_payload(tools)
        if tp:
            payload["tools"] = tp

        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": self.API_VERSION,
            "Content-Type": "application/json",
        }
        url = f"{self.base_url.rstrip('/')}/v1/messages"

        tu_buf: dict[int, dict[str, Any]] = {}

        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream("POST", url, headers=headers, json=payload) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line or not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if not data:
                        continue
                    try:
                        ev = json.loads(data)
                    except json.JSONDecodeError:
                        continue
                    et = ev.get("type")
                    if et == "content_block_start":
                        block = ev.get("content_block") or {}
                        if block.get("type") == "tool_use":
                            tu_buf[ev.get("index", 0)] = {
                                "id": block.get("id", ""),
                                "name": block.get("name", ""),
                                "args": "",
                            }
                    elif et == "content_block_delta":
                        d = ev.get("delta") or {}
                        if d.get("type") == "text_delta":
                            yield LLMStreamChunk(delta_text=d.get("text", ""))
                        elif d.get("type") == "input_json_delta":
                            idx = ev.get("index", 0)
                            buf = tu_buf.get(idx)
                            if buf is not None:
                                buf["args"] += d.get("partial_json", "")
                                args_dict: dict[str, Any] = {}
                                try:
                                    args_dict = json.loads(buf["args"]) if buf["args"].strip() else {}
                                except json.JSONDecodeError:
                                    args_dict = {"_partial": buf["args"]}
                                yield LLMStreamChunk(
                                    tool_call_delta=ToolCall(id=buf["id"], name=buf["name"], arguments=args_dict)
                                )
                    elif et == "message_delta":
                        d = ev.get("delta") or {}
                        fr = d.get("stop_reason")
                        if fr:
                            yield LLMStreamChunk(finish_reason=fr)
                    elif et == "message_stop":
                        return
