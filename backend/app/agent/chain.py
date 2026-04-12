import os
from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain.schema import HumanMessage, SystemMessage
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
    def __init__(self, session: ConversationSession):
        self.session = session
        self.llm = get_llm()
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
                response_content = f"【待确认操作】{action['description']}\n\n请回复"是"确认执行，或其他内容取消。"

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
        """Parse action from LLM response"""
        if "add_student" in response:
            return {"type": "add_student", "description": "添加学生"}
        elif "update_student" in response:
            return {"type": "update_student", "description": "更新学生信息"}
        elif "delete_student" in response:
            return {"type": "delete_student", "description": "删除学生"}
        elif "add_grade" in response:
            return {"type": "add_grade", "description": "录入成绩"}
        return None

    async def _execute_pending_action(self) -> dict:
        """Execute the pending action"""
        action = self.session.pending_action
        self.session.clear_pending_action()

        # TODO: Call MCP tools here (Phase 3 Task 3)
        # Currently MCP tools are not integrated, so we just return a placeholder
        response = f"已执行操作: {action['description']}"
        self.session.add_ai_message(response)

        return {
            "type": "text",
            "content": response,
            "action_executed": True,
        }