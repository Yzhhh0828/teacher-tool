# Architecture

This document captures the post-refactor shape of the codebase, focused on
the modules introduced in the LLM-provider / agent-tools / classroom slice.

## Backend

```
backend/app/
├── agent/
│   ├── chain.py          # AgentChain – coordinates session + LLM call
│   ├── prompts.py        # SYSTEM_PROMPT
│   ├── session.py        # In-memory ConversationSession (TTL = 2h)
│   ├── llm/              # Provider abstraction (NEW)
│   │   ├── base.py           # BaseLLMProvider, ChatMessage, ToolSpec, ToolCall
│   │   ├── factory.py        # get_provider() — dispatches by name + env
│   │   ├── openai_provider.py     # any OpenAI-compatible endpoint
│   │   ├── anthropic_provider.py  # Claude Messages API
│   │   └── ollama_provider.py     # Local Ollama
│   └── tools/            # JSON-schema'd functions exposed to the LLM (NEW)
│       ├── registry.py        # ToolRegistry, decorator
│       ├── student_tools.py   # CRUD + bulk_create_students
│       ├── grade_tools.py     # add_grade + bulk_upsert_grades
│       ├── seating_tools.py   # apply_seating_layout, random_shuffle_seats
│       ├── analytics_tools.py # analyze_class_performance, student_trend
│       ├── classroom_tools.py # pick_random_student, random_groups
│       └── vision_import.py   # parse_*_image — multimodal LLM ingest
├── api/
│   ├── agent.py          # /agent/chat (legacy SSE) + /agent/tools/* (NEW)
│   ├── analytics.py      # NEW – dashboard endpoints
│   ├── classroom.py      # NEW – random pick / groups / event log
│   └── …                 # auth, classes, students, grades, seating, schedules
├── models/
│   ├── agent_action.py   # NEW – audit log for agent-driven writes (undo-ready)
│   ├── classroom.py      # NEW – ClassroomEvent (pick/group/timer history)
│   └── …
└── mcp/                  # Original MCPTools, reused by the new tool layer
```

### Key contracts

**`BaseLLMProvider`** — every provider implements `async stream(...)`
yielding `LLMStreamChunk(delta_text, tool_call_delta, finish_reason)`.
A default `chat()` aggregates the stream into an `LLMResponse`. All
providers accept multi-modal `ChatMessage(content, images=[ImageContent])`
and OpenAI-shape JSON-schema tools.

**`ToolRegistry`** — tools self-register via `@registry.tool(...)`. Each
tool exposes a JSON schema, a Python handler, a `requires_confirmation`
flag and a `category` (`student`, `grade`, `seating`, `analytics`,
`classroom`, `vision`). The `/agent/tools/invoke` endpoint refuses to run
write-tools without `confirmed=true`.

### Agent flow

1. Frontend POSTs to `/agent/chat` with text/image. Per-request override
   headers `X-LLM-Provider`, `X-API-Key`, `X-Base-URL` map to
   `get_provider(...)`.
2. `AgentChain.process` runs an **agentic loop** (max 4 rounds) — it
   calls `llm.chat(messages, tools=registry.specs())` and:
   * read-only tool calls auto-execute and feed back into the next
     round,
   * write tool calls are buffered into `session.pending_action`
     (`kind="tool_calls"`); the response carries the full
     `pending_tool_calls` list so the chat UI can render
     "确认执行 / 取消" buttons (see `chat_screen.dart`).
3. On confirmation, buffered calls are invoked through
   `tool_registry.invoke(...)` (which routes through `MCPTools` and
   audit-logs the result). A summary pass produces the final text.
4. The legacy keyword-detected `pending_action` path still fires when
   the LLM returns plain text containing tool names — this gives
   graceful behaviour for providers without native tool calling.
5. Frontend can also bypass chat and call `/agent/tools/invoke`
   directly: with `confirmed=false` it returns `pending_confirmation`;
   with `confirmed=true` the tool runs.

### Audit log + undo

Write tools call `app.agent.audit.log_action(...)` after a successful
commit, persisting `{payload, diff, undo_payload}` rows on
`AgentAction`. The `/agent/actions` endpoint lists them per-user and
`/agent/actions/{id}/undo` reverses the change via `undo_action(...)`.
Supported reversals today: `bulk_create_students`, `add_student`,
`add_grade`, `bulk_upsert_grades`, `apply_seating_layout`. Re-undoing
an already-undone row returns 400 (`UndoNotSupported`). See
`docs/ai-agent.md` for the full table.

### Storage / migrations

Two parallel paths are supported:

* **Auto-migration** (default for dev / fresh installs): `init_db()`
  runs `Base.metadata.create_all`, plus `ensure_backward_compatible_schema`
  for additive columns on `classes`.
* **Alembic** (for production / shared databases): `backend/alembic.ini`
  + `backend/migrations/`. The baseline revision (`0001_baseline`)
  intentionally calls `Base.metadata.create_all` on the live
  connection, so it stays in sync with the ORM and is idempotent. Run
  `alembic upgrade head` for fresh installs, or `alembic stamp head`
  for installs already created via `init_db()`. New schema changes
  should land as additional revisions using `op.create_table` /
  `op.add_column` so the change log stays auditable.

## Frontend (Flutter)

```
flutter_app/lib/
├── core/
│   ├── design/
│   │   ├── tokens.dart        # NEW – AppSpacing/AppRadius/AppMotion/AppPalette
│   │   └── theme_builder.dart # NEW – buildAppTheme(palette, brightness)
│   └── theme/app_theme.dart   # Legacy warm-orange theme (still default)
├── providers/
│   ├── theme_provider.dart    # NEW – persisted palette + ThemeMode
│   ├── analytics_provider.dart # NEW
│   ├── classroom_provider.dart # NEW
│   └── settings_provider.dart  # extended (provider includes "ollama")
├── data/repositories/
│   ├── analytics_repository.dart # NEW
│   └── classroom_repository.dart # NEW
└── ui/
    ├── widgets/
    │   ├── app_card.dart       # NEW – AppCard + GlassPanel
    │   ├── animated_number.dart # NEW
    │   └── wheel_picker.dart    # NEW – animated NameWheel
    └── screens/
        ├── analytics/analytics_screen.dart   # NEW dashboard
        └── presentation/
            ├── random_pick_screen.dart       # NEW – server-backed pick + wheel
            ├── random_groups_screen.dart     # NEW
            ├── timer_screen.dart             # NEW
            └── random_call_screen.dart       # legacy, kept as fallback
```

The legacy `AppTheme.lightTheme` is still used as the default to avoid any
visual regression on the existing 13 screens. Switching to the
`mellardGreen` palette in Settings rebuilds the theme via the new
`buildAppTheme` factory and re-themes every M3 widget.

## Testing

| Suite | What it covers |
|-------|----------------|
| `tests/test_llm_providers.py` | Provider dispatch, OpenAI/Anthropic/Ollama streaming text + tool-call accumulation, multimodal payload shape |
| `tests/test_agent_tools.py`   | Registry contents, write-tool confirmation flag, `bulk_create_students`, `pick_random_student`, `random_groups` end-to-end on in-memory SQLite |
| `tests/test_analytics_classroom_api.py` | New `/analytics/*` and `/classroom/*` endpoints with auth + event logging |
| `tests/test_agent_chain.py` | Existing chain regression tests, updated for the new provider signature |
| `tests/test_agent_chain_tools.py` | Native tool-calling loop: scripted LLM → read-tool auto-exec, write-tool confirmation, cancellation |
| `tests/test_audit_undo.py` | Audit log persistence, `/agent/actions/*` endpoints, undo of `bulk_create_students`, cross-user permission |
| `tests/test_e2e_full_flow.py` | **E2E**: auth → class → bulk students → exam + bulk grades (via `/agent/tools/invoke`) → analytics overview / distribution / compare → classroom pick + groups + events → audit list → undo |

Frontend smoke tests live at `flutter_app/test/widgets_test.dart` and
cover `AppCard`, `GlassPanel`, `AnimatedNumber`, `NameWheel` plus
palette/theme construction.

```bash
# backend
cd backend && python -m pytest -q   # 66 passed

# frontend
cd flutter_app && flutter pub get && flutter analyze && flutter test
```
