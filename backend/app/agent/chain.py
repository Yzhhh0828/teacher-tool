import json
import re
from typing import Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.llm import get_provider, ChatMessage, ImageContent
from app.agent.llm.base import ToolCall
from app.agent.prompts import SYSTEM_PROMPT
from app.agent.session import ConversationSession, get_session, create_session
from app.agent.tools import registry as tool_registry

# Maximum tool-calling rounds per user turn to bound total LLM calls.
_MAX_TOOL_ROUNDS = 4


def get_llm(override: dict | None = None):
    """Resolve an LLM provider with optional per-request overrides.

    `override` keys: provider, api_key, base_url, model.
    """
    override = override or {}
    return get_provider(
        provider=override.get("provider") or None,
        api_key=override.get("api_key") or None,
        base_url=override.get("base_url") or None,
        model=override.get("model") or None,
    )


class AgentChain:
    def __init__(self, session: ConversationSession, db: AsyncSession = None, llm_override: dict = None):
        self.session = session
        self.llm = get_llm(llm_override)
        self.db = db
        self.confirmation_level = "medium"  # low, medium, high

    def _build_messages(self) -> list[ChatMessage]:
        """Build messages for the unified LLM provider."""
        messages: list[ChatMessage] = [ChatMessage(role="system", content=SYSTEM_PROMPT)]
        for msg in self.session.messages[-10:]:
            if msg["role"] == "user":
                images: list[ImageContent] = []
                img = msg.get("image_url") or msg.get("image")
                if isinstance(img, str) and img:
                    if img.startswith("http://") or img.startswith("https://"):
                        images.append(ImageContent(url=img))
                    elif img.startswith("data:"):
                        try:
                            header, payload = img.split(",", 1)
                            m = re.match(r"data:([^;]+);base64", header)
                            mt = m.group(1) if m else "image/png"
                            images.append(ImageContent(base64=payload, mime_type=mt))
                        except ValueError:
                            pass
                    else:
                        images.append(ImageContent(base64=img))
                messages.append(ChatMessage(role="user", content=msg["content"], images=images))
            else:
                messages.append(ChatMessage(role="assistant", content=msg["content"]))
        return messages

    async def process(
        self,
        user_input: str,
        image_data: Optional[str] = None,
    ) -> dict:
        """Process user input and return response.

        The flow is now driven by native LLM tool-calling:

        1. Append the user message.
        2. If a pending action is queued (legacy keyword path or queued
           tool-calls), an affirmative reply executes it.
        3. Otherwise, run an agentic loop where the LLM may emit tool
           calls. Read-only tools auto-execute and feed their output back
           into the next round; write tools accumulate into
           ``pending_tool_calls`` and the user is asked to confirm.
        """
        self.session.add_user_message(user_input, image_data)

        # ── Confirmation handling (works for both legacy pending_action
        #    dict and the new pending_tool_calls list) ────────────────
        if self.session.pending_action:
            if self._is_affirmative(user_input):
                pa = self.session.pending_action
                if isinstance(pa, dict) and pa.get("kind") == "tool_calls":
                    return await self._execute_pending_tool_calls()
                return await self._execute_pending_action()
            self.session.clear_pending_action()
            response = "操作已取消。有什么其他我可以帮助你的？"
            self.session.add_ai_message(response)
            return {"type": "text", "content": response}

        return await self._run_agentic_loop()

    # ── Agentic loop ─────────────────────────────────────────────────

    async def _run_agentic_loop(self) -> dict:
        tool_specs = tool_registry.specs() if self.db is not None else None
        tool_traces: list[dict[str, Any]] = []

        for _round in range(_MAX_TOOL_ROUNDS):
            messages = self._build_messages()
            try:
                response = await self.llm.chat(messages, tools=tool_specs)
            except Exception as exc:  # network / auth failures
                msg = f"AI 服务调用失败: {exc}"
                self.session.add_ai_message(msg)
                return {"type": "text", "content": msg, "action_executed": False}

            # No tool calls — terminate with the assistant text.
            if not response.tool_calls:
                text = response.text or ""
                # Backward-compat: still respect old keyword-based action emission
                if self._needs_confirmation(text):
                    action = self._parse_action(text)
                    if action:
                        self.session.set_pending_action(action)
                        text = f'【待确认操作】{action["description"]}\n\n请回复"是"确认执行，或其他内容取消。'
                self.session.add_ai_message(text)
                return {
                    "type": "text",
                    "content": text,
                    "needs_confirmation": self.session.pending_action is not None,
                    "action_executed": False,
                    "tool_traces": tool_traces,
                }

            # Split tool calls into read/write.
            read_calls, write_calls = self._partition_tool_calls(response.tool_calls)

            if write_calls:
                # Queue write calls for explicit user confirmation.
                desc = "、".join(f"{tc.name}" for tc in write_calls)
                pending = {
                    "kind": "tool_calls",
                    "description": f"将执行写入操作：{desc}",
                    "tool_calls": [
                        {"id": tc.id, "name": tc.name, "arguments": tc.arguments}
                        for tc in write_calls
                    ],
                    # Auto-executed reads are also committed so the next round
                    # can see them, but they're NOT part of the confirmation.
                    "preview_reads": [
                        {"name": tc.name, "arguments": tc.arguments}
                        for tc in read_calls
                    ],
                }
                self.session.set_pending_action(pending)
                preview = self._format_tool_call_preview(write_calls)
                msg = (
                    f"【待确认操作】{pending['description']}\n\n{preview}\n\n"
                    "请回复\"是\"确认执行，或其他内容取消。"
                )
                self.session.add_ai_message(msg)
                return {
                    "type": "text",
                    "content": msg,
                    "needs_confirmation": True,
                    "action_executed": False,
                    "pending_tool_calls": pending["tool_calls"],
                    "tool_traces": tool_traces,
                }

            # Only read tools — execute them and continue.
            for tc in read_calls:
                trace = await self._invoke_tool(tc)
                tool_traces.append(trace)
                self._append_tool_message(tc, trace)

        # Hit the round cap.
        msg = "AI 在多轮工具调用后仍未给出最终答复，请重新提问。"
        self.session.add_ai_message(msg)
        return {"type": "text", "content": msg, "tool_traces": tool_traces}

    async def _execute_pending_tool_calls(self) -> dict:
        pending = self.session.pending_action
        self.session.clear_pending_action()
        traces: list[dict[str, Any]] = []
        for raw in pending.get("tool_calls", []):
            tc = ToolCall(id=raw.get("id") or raw["name"], name=raw["name"], arguments=raw.get("arguments") or {})
            trace = await self._invoke_tool(tc)
            traces.append(trace)
            self._append_tool_message(tc, trace)

        # Optional summarisation pass — best-effort.
        summary = "已完成请求的写入操作。"
        try:
            response = await self.llm.chat(self._build_messages(), tools=None)
            if response.text.strip():
                summary = response.text.strip()
        except Exception:
            pass

        self.session.add_ai_message(summary)
        return {
            "type": "text",
            "content": summary,
            "action_executed": True,
            "tool_traces": traces,
        }

    # ── Tool invocation helpers ─────────────────────────────────────

    def _partition_tool_calls(self, calls: list[ToolCall]) -> tuple[list[ToolCall], list[ToolCall]]:
        read: list[ToolCall] = []
        write: list[ToolCall] = []
        for tc in calls:
            tool = tool_registry.get(tc.name)
            if tool is not None and tool.requires_confirmation:
                write.append(tc)
            else:
                read.append(tc)
        return read, write

    async def _invoke_tool(self, tc: ToolCall) -> dict[str, Any]:
        try:
            result = await tool_registry.invoke(
                tc.name, db=self.db, user_id=self.session.user_id, **(tc.arguments or {})
            )
            return {"name": tc.name, "arguments": tc.arguments, "ok": True, "result": result}
        except Exception as exc:
            return {"name": tc.name, "arguments": tc.arguments, "ok": False, "error": str(exc)}

    def _append_tool_message(self, tc: ToolCall, trace: dict[str, Any]) -> None:
        body = json.dumps(trace.get("result") if trace["ok"] else {"error": trace.get("error")}, ensure_ascii=False)
        # Stored on the session as an assistant message tagged with the tool name
        # (the in-memory session model only supports user/assistant roles).
        self.session.messages.append({
            "role": "assistant",
            "content": f"[tool:{tc.name}] {body}",
            "tool_name": tc.name,
            "tool_arguments": tc.arguments,
            "tool_ok": trace["ok"],
        })

    @staticmethod
    def _format_tool_call_preview(calls: list[ToolCall]) -> str:
        lines: list[str] = []
        for tc in calls:
            args = json.dumps(tc.arguments or {}, ensure_ascii=False)
            lines.append(f"• {tc.name} {args}")
        return "\n".join(lines)

    @staticmethod
    def _is_affirmative(text: str) -> bool:
        return text.strip().lower() in {"是", "确认", "确定", "yes", "y", "ok", "好"}

    def _needs_confirmation(self, response: str) -> bool:
        """Check if response contains an action that needs confirmation"""
        action_keywords = ["add_student", "update_student", "delete_student",
                          "add_grade", "update_seating", "random_shuffle_seats"]
        return any(keyword in response for keyword in action_keywords)

    def _parse_action(self, response: str) -> Optional[dict]:
        """Parse action and parameters from LLM response"""
        # Try to find JSON in response
        json_match = re.search(r'\{[^{}]*"type"\s*:\s*"[^"]+"(?:,\s*"[^"]+"\s*:\s*[^}]+)*\}', response)
        if json_match:
            try:
                data = json.loads(json_match.group())
                return {
                    "type": data.get("type"),
                    "description": data.get("description", ""),
                    "params": data.get("params", {}),
                }
            except json.JSONDecodeError:
                pass

        # Fallback to keyword matching (less reliable)
        if "add_student" in response:
            return {"type": "add_student", "description": "添加学生", "params": {}}
        elif "update_student" in response:
            return {"type": "update_student", "description": "更新学生信息", "params": {}}
        elif "delete_student" in response:
            return {"type": "delete_student", "description": "删除学生", "params": {}}
        elif "add_grade" in response:
            return {"type": "add_grade", "description": "录入成绩", "params": {}}
        return None

    def _validate_action_params(self, action_type: str, params: dict) -> Optional[str]:
        required_params = {
            "add_student": {"class_id", "name", "gender"},
            "update_student": {"student_id"},
            "delete_student": {"student_id"},
            "add_grade": {"exam_id", "student_id", "subject", "score"},
            "update_seating": {"class_id", "seats"},
            "random_shuffle_seats": {"class_id"},
        }

        missing = sorted(
            required_params.get(action_type, set()) - set(params.keys())
        )
        if missing:
            return f"缺少必要参数：{', '.join(missing)}"
        return None

    async def _execute_pending_action(self) -> dict:
        """Execute the pending action using MCP tools"""
        action = self.session.pending_action
        self.session.clear_pending_action()

        if not self.db:
            response = f"已执行操作: {action['description']} (db not available)"
            self.session.add_ai_message(response)
            return {"type": "text", "content": response, "action_executed": True}

        from app.mcp.tools import MCPTools
        mcp = MCPTools(self.db, self.session.user_id)

        try:
            action_type = action["type"]
            params = action.get("params", {})
            validation_error = self._validate_action_params(action_type, params)
            if validation_error:
                response = validation_error
                self.session.add_ai_message(response)
                return {"type": "text", "content": response, "action_executed": True}

            if action_type == "add_student":
                result = await mcp.add_student(**params)
                response = f"成功添加学生: {result.get('name', '未知')}"
            elif action_type == "update_student":
                result = await mcp.update_student(**params)
                response = f"成功更新学生信息: {result.get('name', '未知')}"
            elif action_type == "delete_student":
                result = await mcp.delete_student(**params)
                response = f"成功删除学生: {result.get('message', '')}"
            elif action_type == "add_grade":
                result = await mcp.add_grade(**params)
                response = f"成功录入成绩: {result.get('id', '未知')}"
            elif action_type == "update_seating":
                result = await mcp.update_seating(**params)
                if isinstance(result, dict) and result.get("success") is False:
                    response = f"操作失败: {result.get('message', '未知错误')}"
                else:
                    response = "成功更新座位表"
            elif action_type == "random_shuffle_seats":
                result = await mcp.random_shuffle_seats(**params)
                if isinstance(result, dict) and result.get("success") is False:
                    response = f"操作失败: {result.get('message', '未知错误')}"
                else:
                    response = "成功随机换座位"
            else:
                response = f"操作类型未知: {action_type}"
        except Exception as e:
            response = f"操作失败: {str(e)}"

        self.session.add_ai_message(response)
        return {"type": "text", "content": response, "action_executed": True}