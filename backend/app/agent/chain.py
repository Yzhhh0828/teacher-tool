import os
import json
import re
from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, SystemMessage
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.agent.prompts import SYSTEM_PROMPT
from app.agent.session import ConversationSession, get_session, create_session


def get_llm():
    """Get LLM client based on configuration"""
    if settings.LLM_PROVIDER == "openai":
        return ChatOpenAI(
            api_key=settings.OPENAI_API_KEY,
            base_url=settings.OPENAI_BASE_URL,
            model="gpt-4o",
            streaming=True,
        )
    elif settings.LLM_PROVIDER == "anthropic":
        return ChatAnthropic(
            api_key=settings.ANTHROPIC_API_KEY,
            base_url=settings.ANTHROPIC_BASE_URL,
            model="claude-sonnet-4-6-20250514",
            streaming=True,
        )
    else:
        raise ValueError(f"Unknown LLM provider: {settings.LLM_PROVIDER}")


class AgentChain:
    def __init__(self, session: ConversationSession, db: AsyncSession = None):
        self.session = session
        self.llm = get_llm()
        self.db = db
        self.confirmation_level = "medium"  # low, medium, high

    def _build_messages(self) -> list:
        """Build messages for LLM"""
        messages = [SystemMessage(content=SYSTEM_PROMPT)]

        for msg in self.session.messages[-10:]:  # Last 10 messages for context
            if msg["role"] == "user":
                content = msg["content"]
                if msg.get("image_url"):
                    content = f"[图片上传]\n{content}"
                messages.append(HumanMessage(content=content))
            else:
                messages.append(HumanMessage(content=msg["content"]))

        return messages

    async def process(
        self,
        user_input: str,
        image_data: Optional[str] = None,
    ) -> dict:
        """Process user input and return response"""

        # Add user message to session
        self.session.add_user_message(user_input, image_data)

        # Check if there's a pending action
        if self.session.pending_action:
            if user_input.lower() in ["是", "确认", "确定", "yes", "y"]:
                # Execute pending action
                return await self._execute_pending_action()
            else:
                # Cancel action
                self.session.clear_pending_action()
                response = "操作已取消。有什么其他我可以帮助你的？"
                self.session.add_ai_message(response)
                return {"type": "text", "content": response}

        # Build messages and call LLM
        messages = self._build_messages()

        # Stream response
        response_content = ""
        async for chunk in self.llm.astream(messages):
            if chunk.content:
                response_content += chunk.content

        # Check if we need confirmation
        if self._needs_confirmation(response_content):
            # Parse and store pending action
            action = self._parse_action(response_content)
            if action:
                self.session.set_pending_action(action)
                # Modify response to ask for confirmation
                response_content = f'【待确认操作】{action["description"]}\n\n请回复"是"确认执行，或其他内容取消。'

        self.session.add_ai_message(response_content)

        return {
            "type": "text",
            "content": response_content,
            "needs_confirmation": self.session.pending_action is not None,
            "action_executed": False,
        }

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