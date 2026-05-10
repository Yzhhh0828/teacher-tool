"""Ollama provider (`/api/chat`) — supports llava/llama vision + tools."""
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


class OllamaProvider(BaseLLMProvider):
    name = "ollama"
    supports_vision = True
    supports_tools = True

    DEFAULT_MODEL = "llama3.2"
    DEFAULT_BASE_URL = "http://localhost:11434"

    def __init__(self, api_key: str = "", base_url: Optional[str] = None, model: Optional[str] = None, **kwargs: Any) -> None:
        super().__init__(api_key=api_key, base_url=base_url or self.DEFAULT_BASE_URL, model=model or self.DEFAULT_MODEL, **kwargs)

    @staticmethod
    def _msg_to_dict(msg: ChatMessage) -> dict[str, Any]:
        d: dict[str, Any] = {"role": msg.role, "content": msg.content or ""}
        if msg.images:
            # Ollama wants raw base64 strings (no data URL prefix)
            d["images"] = [img.base64 for img in msg.images if img.base64]
        if msg.role == "assistant" and msg.tool_calls:
            d["tool_calls"] = [
                {"function": {"name": tc.name, "arguments": tc.arguments}}
                for tc in msg.tool_calls
            ]
        if msg.role == "tool":
            d["tool_call_id"] = msg.tool_call_id or ""
        return d

    @staticmethod
    def _tools_to_payload(tools: Optional[list[ToolSpec]]) -> Optional[list[dict[str, Any]]]:
        if not tools:
            return None
        return [
            {
                "type": "function",
                "function": {
                    "name": t.name,
                    "description": t.description,
                    "parameters": t.parameters,
                },
            }
            for t in tools
        ]

    async def stream(
        self,
        messages: list[ChatMessage],
        tools: Optional[list[ToolSpec]] = None,
        temperature: float = 0.7,
        **kwargs: Any,
    ) -> AsyncIterator[LLMStreamChunk]:
        payload: dict[str, Any] = {
            "model": kwargs.get("model") or self.model,
            "messages": [self._msg_to_dict(m) for m in messages],
            "stream": True,
            "options": {"temperature": temperature},
        }
        tp = self._tools_to_payload(tools)
        if tp:
            payload["tools"] = tp

        url = f"{self.base_url.rstrip('/')}/api/chat"
        async with httpx.AsyncClient(timeout=300.0) as client:
            async with client.stream("POST", url, json=payload) as resp:
                resp.raise_for_status()
                tc_idx = 0
                async for line in resp.aiter_lines():
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    msg = obj.get("message") or {}
                    if msg.get("content"):
                        yield LLMStreamChunk(delta_text=msg["content"])
                    for tc in msg.get("tool_calls") or []:
                        fn = tc.get("function") or {}
                        args = fn.get("arguments") or {}
                        if isinstance(args, str):
                            try:
                                args = json.loads(args)
                            except json.JSONDecodeError:
                                args = {"_raw": args}
                        yield LLMStreamChunk(
                            tool_call_delta=ToolCall(
                                id=tc.get("id") or f"call_{tc_idx}",
                                name=fn.get("name", ""),
                                arguments=args,
                            )
                        )
                        tc_idx += 1
                    if obj.get("done"):
                        yield LLMStreamChunk(finish_reason=obj.get("done_reason") or "stop")
                        return
