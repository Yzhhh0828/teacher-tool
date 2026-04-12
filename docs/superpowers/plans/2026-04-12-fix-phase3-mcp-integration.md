# Phase 3 MCP 集成修复计划

**Goal:** 让 AgentChain 真正调用 MCP 工具执行实际操作

**Architecture:** 修改 AgentChain 接收数据库会话，在确认执行时调用实际 MCP 工具

**Tech Stack:** Python asyncio, SQLAlchemy AsyncSession, MCPTools

---

## 问题分析

当前流程：
1. LLM 返回文本包含 `add_student` 等关键字
2. `_parse_action()` 只提取类型，不提取参数
3. `_execute_pending_action()` 是空实现，只返回占位符

需要修复：
1. `AgentChain` 需要接收 `db` 和 `user_id`
2. `_parse_action` 需要从 LLM 响应中提取参数（需要 LLM 输出 JSON）
3. `_execute_pending_action` 需要真正调用 `MCPTools`

---

## Task 1: 修改 AgentChain 集成 MCP 工具

**Files:**
- Modify: `backend/app/agent/chain.py`
- Modify: `backend/app/api/agent.py`

- [ ] **Step 1: 修改 AgentChain 接收 db session**

```python
class AgentChain:
    def __init__(self, session: ConversationSession, db: AsyncSession = None):
        self.session = session
        self.llm = get_llm()
        self.db = db
        self.confirmation_level = "medium"
```

- [ ] **Step 2: 修改 _parse_action 从 JSON 中提取参数**

```python
def _parse_action(self, response: str) -> Optional[dict]:
    """Parse action and parameters from LLM response"""
    import json
    import re

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
```

- [ ] **Step 3: 修改 _execute_pending_action 真正调用 MCP 工具**

```python
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
            response = "成功更新座位表"
        elif action_type == "random_shuffle_seats":
            result = await mcp.random_shuffle_seats(**params)
            response = "成功随机换座位"
        else:
            response = f"操作类型未知: {action_type}"
    except Exception as e:
        response = f"操作失败: {str(e)}"

    self.session.add_ai_message(response)
    return {"type": "text", "content": response, "action_executed": True}
```

- [ ] **Step 4: 修改 api/agent.py 传递 db 到 AgentChain**

```python
@router.post("/chat")
async def chat(
    message: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ... session creation code ...

    # Create agent chain with db
    agent = AgentChain(session, db)

    async def event_generator():
        # ... existing code ...
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/agent/chain.py backend/app/api/agent.py
git commit -m "fix: integrate MCP tools into AgentChain execution"
```

---

## Task 2: 更新 System Prompt 要求结构化输出

**Files:**
- Modify: `backend/app/agent/prompts.py`

- [ ] **Step 1: 更新 SYSTEM_PROMPT 要求 JSON 输出**

```python
SYSTEM_PROMPT = """You are a helpful AI assistant for a teacher tool. Your role is to help teachers manage their classes.

When you need to perform an action (ADD, UPDATE, DELETE), you must output a JSON object in your response:

{
    "type": "add_student|update_student|delete_student|add_grade|update_seating|random_shuffle_seats",
    "description": "Description of the action in Chinese",
    "params": {
        // Parameters for the action, e.g.:
        // "class_id": 1,
        // "name": "学生姓名",
        // "gender": "男|女"
    }
}

IMPORTANT RULES:
1. Before using any tool, you must ask for user confirmation
2. For any ADD, UPDATE, or DELETE operations, include the JSON above and wait for confirmation
3. Only execute operations after user explicitly confirms with "是" or "yes"
4. When displaying data, be clear and organized
5. If you need to know the class_id, ask the user or list their classes first

Your response should be:
- Concise and helpful
- In Chinese (as the user is speaking Chinese)
- Clear about what action will be taken
"""
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/agent/prompts.py
git commit -m "fix: update system prompt for structured JSON output"
```

---

## 自检清单

- [ ] `AgentChain` 接收 `db` 参数
- [ ] `_parse_action` 能从 JSON 中提取参数
- [ ] `_execute_pending_action` 真正调用 `MCPTools`
- [ ] `api/agent.py` 传递 `db` 到 `AgentChain`
- [ ] `SYSTEM_PROMPT` 要求 JSON 格式输出
