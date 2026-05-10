"""OpenAI-compatible Chat Completions provider (works with OpenAI, DeepSeek,
Moonshot, Zhipu, vLLM, LM Studio, etc. — anything that speaks the
`/v1/chat/completions` schema).
"""
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


class OpenAIProvider(BaseLLMProvider):
    name = "openai"
    supports_vision = True
    supports_tools = True

    DEFAULT_MODEL = "gpt-4o-mini"
    DEFAULT_BASE_URL = "https://api.openai.com/v1"

    def __init__(self, api_key: str = "", base_url: Optional[str] = None, model: Optional[str] = None, **kwargs: Any) -> None:
        super().__init__(api_key=api_key, base_url=base_url or self.DEFAULT_BASE_URL, model=model or self.DEFAULT_MODEL, **kwargs)

    # ---------- message conversion ----------
    @staticmethod
    def _msg_to_dict(msg: ChatMessage) -> dict[str, Any]:
        # Multimodal user messages: content becomes a list of parts.
        if msg.role == "user" and msg.images:
            parts: list[dict[str, Any]] = []
            if msg.content:
                parts.append({"type": "text", "text": msg.content})
            for img in msg.images:
                parts.append({"type": "image_url", "image_url": {"url": img.to_data_url()}})
            return {"role": "user", "content": parts}

        if msg.role == "tool":
            return {
                "role": "tool",
                "tool_call_id": msg.tool_call_id or "",
                "content": msg.content,
            }

        if msg.role == "assistant" and msg.tool_calls:
            return {
                "role": "assistant",
                "content": msg.content or None,
                "tool_calls": [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {"name": tc.name, "arguments": json.dumps(tc.arguments, ensure_ascii=False)},
                    }
                    for tc in msg.tool_calls
                ],
            }

        return {"role": msg.role, "content": msg.content}

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
            "temperature": temperature,
            "stream": True,
        }
        tools_payload = self._tools_to_payload(tools)
        if tools_payload:
            payload["tools"] = tools_payload

        headers = {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}
        url = f"{self.base_url.rstrip('/')}/chat/completions"

        # tool-call accumulator keyed by index (OpenAI streams partial tool args by index)
        tc_buf: dict[int, dict[str, Any]] = {}

        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream("POST", url, headers=headers, json=payload) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line or not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if data == "[DONE]":
                        break
                    try:
                        obj = json.loads(data)
                    except json.JSONDecodeError:
                        continue
                    choice = (obj.get("choices") or [{}])[0]
                    delta = choice.get("delta") or {}
                    finish = choice.get("finish_reason")

                    text = delta.get("content")
                    tool_calls = delta.get("tool_calls")

                    if text:
                        yield LLMStreamChunk(delta_text=text)
                    if tool_calls:
                        for tc in tool_calls:
                            idx = tc.get("index", 0)
                            buf = tc_buf.setdefault(idx, {"id": "", "name": "", "args": ""})
                            if tc.get("id"):
                                buf["id"] = tc["id"]
                            fn = tc.get("function") or {}
                            if fn.get("name"):
                                buf["name"] = fn["name"]
                            if fn.get("arguments"):
                                buf["args"] += fn["arguments"]
                            # emit incremental delta with parsed-so-far args (best effort)
                            args_dict: dict[str, Any] = {}
                            try:
                                args_dict = json.loads(buf["args"]) if buf["args"].strip() else {}
                            except json.JSONDecodeError:
                                args_dict = {"_partial": buf["args"]}
                            yield LLMStreamChunk(
                                tool_call_delta=ToolCall(id=buf["id"] or f"call_{idx}", name=buf["name"], arguments=args_dict)
                            )
                    if finish:
                        yield LLMStreamChunk(finish_reason=finish)
