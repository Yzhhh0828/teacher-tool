"""Vision-based bulk import: parse images of rosters / seating / grade-sheets
into structured payloads using the active LLM provider's multimodal API.
"""
from __future__ import annotations

import base64
import json
import re
from typing import Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.llm import ChatMessage, ImageContent, get_provider
from app.agent.tools.registry import registry


def _decode_image(image: str, mime_type: str = "image/png") -> ImageContent:
    """Accept either a data URL, a remote URL, or raw base64."""
    if image.startswith("http://") or image.startswith("https://"):
        return ImageContent(url=image, mime_type=mime_type)
    if image.startswith("data:"):
        # data:<mime>;base64,<payload>
        try:
            header, payload = image.split(",", 1)
            m = re.match(r"data:([^;]+);base64", header)
            mt = m.group(1) if m else mime_type
            return ImageContent(base64=payload, mime_type=mt)
        except ValueError:
            return ImageContent(base64=image, mime_type=mime_type)
    # plain base64
    return ImageContent(base64=image, mime_type=mime_type)


def _extract_json(text: str) -> Any:
    """Best-effort JSON extraction from a possibly-chatty LLM reply."""
    text = text.strip()
    # try fenced code block first
    m = re.search(r"```(?:json)?\s*([\s\S]+?)```", text)
    candidate = m.group(1).strip() if m else text
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        pass
    # last-resort: find first [...] or {...} block
    m = re.search(r"(\[[\s\S]*\]|\{[\s\S]*\})", text)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass
    return None


_ROSTER_PROMPT = (
    "你是教务录入助手。请从这张学生名单图片中识别每位学生的信息，"
    "严格输出 JSON 数组（不要任何额外说明），每项字段：name(必填)、"
    "gender(male/female/other)、student_no、phone、parent_phone、"
    "parent_name、address、home_phone、hobbies、health、"
    "emergency_contact、birthday(YYYY-MM-DD)、description。"
    "无法识别的字段省略。"
)

_SEATING_PROMPT = (
    "请把这张座位表图片识别为二维网格。每个格子是学生姓名（字符串）或 null（空座）。"
    "严格输出 JSON：{\"rows\": int, \"cols\": int, \"grid\": [[...], ...]}，不要任何多余说明。"
)

_GRADE_PROMPT = (
    "请从这张成绩单图片中识别每条成绩，输出 JSON 数组，每项：student_name、subject、score(数字)。"
    "不要任何多余说明。"
)


async def _call_vision(prompt: str, image: ImageContent, llm_override: Optional[dict] = None) -> Any:
    provider = get_provider(**(llm_override or {}))
    messages = [
        ChatMessage(role="system", content="You output strict JSON only. No prose."),
        ChatMessage(role="user", content=prompt, images=[image]),
    ]
    resp = await provider.chat(messages, temperature=0.0)
    return _extract_json(resp.text)


@registry.tool(
    name="parse_student_roster_image",
    description="解析学生名单图片为结构化数组（不写库）。",
    parameters={
        "type": "object",
        "properties": {
            "image": {"type": "string", "description": "data URL / http URL / 纯 base64"},
            "mime_type": {"type": "string", "default": "image/png"},
        },
        "required": ["image"],
    },
    category="vision",
)
async def parse_student_roster_image(
    *,
    db: AsyncSession,
    user_id: int,
    image: str,
    mime_type: str = "image/png",
    llm_override: Optional[dict] = None,
) -> dict[str, Any]:
    img = _decode_image(image, mime_type)
    data = await _call_vision(_ROSTER_PROMPT, img, llm_override)
    items = data if isinstance(data, list) else []
    return {"items": items, "count": len(items)}


@registry.tool(
    name="parse_seating_chart_image",
    description="解析座位表图片为二维网格（不写库）。",
    parameters={
        "type": "object",
        "properties": {
            "image": {"type": "string"},
            "mime_type": {"type": "string", "default": "image/png"},
        },
        "required": ["image"],
    },
    category="vision",
)
async def parse_seating_chart_image(
    *,
    db: AsyncSession,
    user_id: int,
    image: str,
    mime_type: str = "image/png",
    llm_override: Optional[dict] = None,
) -> dict[str, Any]:
    img = _decode_image(image, mime_type)
    data = await _call_vision(_SEATING_PROMPT, img, llm_override) or {}
    grid = data.get("grid") if isinstance(data, dict) else None
    return {
        "rows": (data.get("rows") if isinstance(data, dict) else None) or (len(grid) if grid else 0),
        "cols": (data.get("cols") if isinstance(data, dict) else None)
        or (max((len(r) for r in grid), default=0) if grid else 0),
        "grid": grid or [],
    }


@registry.tool(
    name="parse_grade_sheet_image",
    description="解析成绩单图片为结构化数组（不写库）。",
    parameters={
        "type": "object",
        "properties": {
            "image": {"type": "string"},
            "mime_type": {"type": "string", "default": "image/png"},
        },
        "required": ["image"],
    },
    category="vision",
)
async def parse_grade_sheet_image(
    *,
    db: AsyncSession,
    user_id: int,
    image: str,
    mime_type: str = "image/png",
    llm_override: Optional[dict] = None,
) -> dict[str, Any]:
    img = _decode_image(image, mime_type)
    data = await _call_vision(_GRADE_PROMPT, img, llm_override)
    items = data if isinstance(data, list) else []
    return {"items": items, "count": len(items)}


# Helper: encode local bytes to base64 (used by tests)
def encode_bytes_to_b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")
