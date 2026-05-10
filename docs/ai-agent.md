# AI Agent

## Provider abstraction

```python
from app.agent.llm import get_provider, ChatMessage, ImageContent, ToolSpec

provider = get_provider(provider="openai", model="gpt-4o-mini")
async for chunk in provider.stream(
    [
        ChatMessage(role="system", content="You are a teaching assistant."),
        ChatMessage(role="user", content="What is in this image?", images=[
            ImageContent(base64=b64_png, mime_type="image/png"),
        ]),
    ],
    tools=[ToolSpec(name="add_student", description="...", parameters={...})],
):
    print(chunk.delta_text, end="")
```

`get_provider()` accepts:
* `provider` — `openai` (default), `anthropic`, `ollama`, or any custom
  provider added to the `_REGISTRY` dict in `factory.py`.
* `api_key`, `base_url`, `model` — all optional. Falsy values fall back
  to `Settings` (`OPENAI_API_KEY`, `OLLAMA_BASE_URL`, etc.).

The frontend can override per-request via headers
`X-LLM-Provider` / `X-API-Key` / `X-Base-URL`.

## Tool registry

Each tool registers itself once at import time:

```python
@registry.tool(
    name="bulk_create_students",
    description="…",
    parameters={"type": "object", "properties": {…}, "required": [...]},
    requires_confirmation=True,
    category="student",
)
async def bulk_create_students(*, db, user_id, class_id, items): ...
```

* `parameters` is a JSON schema passed verbatim to the LLM via
  `ToolSpec.to_spec()`.
* `requires_confirmation=True` is the default for any write — the
  HTTP path `POST /agent/tools/invoke` will return
  `{"status": "pending_confirmation", ...}` until the client retries
  with `confirmed=true`.
* Tools never call `MCPTools.check_class_permission` lazily — they
  always validate up front so a denied request is cheap.

### Built-in categories

| Category | Tools |
|----------|-------|
| `student` | `list_students`, `add_student`, `bulk_create_students`, `update_student`, `delete_student` |
| `grade` | `list_grades`, `add_grade`, `bulk_upsert_grades` |
| `seating` | `get_seating`, `apply_seating_layout`, `random_shuffle_seats` |
| `analytics` | `analyze_class_performance`, `student_trend` |
| `classroom` | `pick_random_student`, `random_groups` |
| `vision` | `parse_student_roster_image`, `parse_seating_chart_image`, `parse_grade_sheet_image` |

The vision tools internally call the **active provider** with multimodal
input and parse the strict-JSON reply — they're framework-free and work
with any provider that supports image inputs.

## HTTP surface

| Method + path | Purpose |
|---------------|---------|
| `GET  /api/v1/agent/providers` | List supported provider names |
| `GET  /api/v1/agent/tools` | List all tools (optionally filtered by `?category=`) |
| `POST /api/v1/agent/tools/invoke` | `{name, arguments, confirmed}` — direct invocation |
| `POST /api/v1/agent/chat` | SSE chat. Drives a native tool-calling loop and emits `pending_tool_calls` for writes |
| `GET  /api/v1/agent/history/{session_id}` | Session messages |
| `DELETE /api/v1/agent/history/{session_id}` | Clear a session |
| `GET  /api/v1/agent/actions` | Recent audit-logged actions for the current user |
| `POST /api/v1/agent/actions/{id}/undo` | Reverse a previously committed write |

All endpoints require `Authorization: Bearer <token>`.

## Audit log + undo

Every write tool calls `app.agent.audit.log_action(...)` after a
successful commit. The row stores:

* `payload` — sanitised arguments the tool ran with
* `diff` — counts (`{created, updated, skipped, names}`) returned to
  the user for review
* `undo_payload` — IDs / snapshots needed to reverse the action

`undo_action(db, user_id, action_id)` then handles the reversal:

| Action type | Reversal |
|-------------|----------|
| `bulk_create_students` / `add_student` | Delete the rows whose IDs are in `created_student_ids` |
| `add_grade` | Delete the row whose ID is `created_grade_id` |
| `bulk_upsert_grades` | Delete `created_grade_ids` and restore `updated_grade_snapshots` |
| `apply_seating_layout` | Restore `previous_seats` for the class |

`AgentAction.status` flips from `committed` → `undone`. Re-attempting
the same undo is rejected with HTTP 400 (mapped from
`UndoNotSupported`).

## Native tool-calling flow (`AgentChain`)

`AgentChain.process(text, image)` performs an agentic loop:

1. Append the user message to the session.
2. If a pending action / pending tool calls exist, an affirmative reply
   (`是 / 确认 / yes / ok …`) executes them; anything else cancels.
3. Otherwise, call `llm.chat(messages, tools=registry.specs())`.
4. **Read-only tools** auto-execute, their result is appended to the
   message stream, and the loop continues (capped at 4 rounds).
5. **Write tools** (`requires_confirmation=True`) are buffered into
   `session.pending_action = {"kind": "tool_calls", "tool_calls": [...]}`.
   The reply contains a human-readable preview plus the full
   `pending_tool_calls` list — the frontend renders the
   "确认执行 / 取消" buttons (see `chat_screen.dart`).
6. On confirmation the buffered calls run via `tool_registry.invoke`,
   each result is appended, and a final summarisation pass produces
   the assistant message.

This flow degrades gracefully when the provider doesn't return
`tool_calls` — the legacy keyword-detection path still kicks in for
free-text plans like `add_student(...)`.

## Adding a new provider

1. Subclass `BaseLLMProvider` and implement `stream()`. Yield
   `LLMStreamChunk` instances.
2. Add the class to `_REGISTRY` in `factory.py`.
3. Optionally add settings fields to `app/config.py`.
4. Add a unit test mirroring `tests/test_llm_providers.py` that
   patches `httpx.AsyncClient.stream` to feed canned chunks.

That's it — the chain, tool registry, agent endpoints, and frontend
provider switcher all pick up the new name automatically.
