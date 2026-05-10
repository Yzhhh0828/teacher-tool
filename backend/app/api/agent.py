import uuid
import json
from typing import Any, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.user import User
from app.api.deps import get_current_user
from app.agent.chain import AgentChain
from app.agent.session import get_session, create_session, delete_session
from app.agent.tools import registry as tool_registry
from app.agent.llm import available_providers, request_override
from app.agent.audit import undo_action, UndoNotSupported
from app.models.agent_action import AgentAction
from sqlalchemy import select, desc
from sse_starlette.sse import EventSourceResponse

class ChatRequest(BaseModel):
    content: str
    session_id: Optional[str] = None
    image: Optional[str] = None

router = APIRouter(prefix="/agent", tags=["agent"])


@router.post("/chat")
async def chat(
    request: Request,
    message: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Send a message to the agent.
    Returns SSE stream for real-time responses.
    """
    user_input = message.content
    image_data = message.image
    session_id = message.session_id

    # Get or create session
    if session_id:
        session = get_session(session_id)
        if not session:
            session = create_session(session_id, current_user.id)
        elif session.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorized")
    else:
        session_id = str(uuid.uuid4())
        session = create_session(session_id, current_user.id)

    # Read optional LLM override headers from frontend settings.
    # `_read_llm_override` strips empties so the factory can fall back to env.
    llm_override = _read_llm_override(request)

    # Create agent chain with db
    agent = AgentChain(session, db, llm_override=llm_override)

    async def event_generator():
        try:
            # Bind the override for any downstream code (e.g. vision tools)
            # invoked inside the agentic loop.
            with request_override(llm_override):
                result = await agent.process(user_input, image_data)

            # Send response
            yield {
                "event": "message",
                "data": json.dumps({
                    "content": result["content"],
                    "session_id": session_id,
                    "needs_confirmation": result.get("needs_confirmation", False),
                    "action_executed": result.get("action_executed", False),
                    "pending_tool_calls": result.get("pending_tool_calls"),
                    "tool_traces": result.get("tool_traces"),
                }),
            }

            # Send done signal
            yield {"event": "done", "data": ""}

        except Exception as e:
            yield {
                "event": "error",
                "data": json.dumps({"error": str(e)}),
            }

    return EventSourceResponse(event_generator())


def _read_llm_override(request: Request) -> dict:
    """Extract LLM provider override from per-request headers.

    Empty strings are dropped so the factory's env-defaults still apply.
    """
    raw = {
        "provider": request.headers.get("X-LLM-Provider"),
        "api_key": request.headers.get("X-API-Key"),
        "base_url": request.headers.get("X-Base-URL"),
        "model": request.headers.get("X-LLM-Model"),
    }
    return {k: v for k, v in raw.items() if v}


@router.get("/history/{session_id}")
async def get_history(
    session_id: str,
    current_user: User = Depends(get_current_user),
):
    """Get conversation history for a session"""
    session = get_session(session_id)

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    return {
        "session_id": session_id,
        "messages": session.messages,
    }


@router.delete("/history/{session_id}")
async def delete_history(
    session_id: str,
    current_user: User = Depends(get_current_user),
):
    """Delete a conversation session"""
    session = get_session(session_id)

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    delete_session(session_id)
    return {"success": True}


# ----------------- v2: tool listing & direct invocation -----------------


@router.get("/providers")
async def list_providers(_: User = Depends(get_current_user)) -> dict[str, Any]:
    return {"providers": available_providers()}


@router.post("/test_connection")
async def test_connection(
    request: Request,
    _: User = Depends(get_current_user),
) -> dict[str, Any]:
    """Round-trip a 1-token "ping" through the configured provider.

    The frontend Settings screen calls this to verify the user-supplied
    API key / base URL / model actually reach the provider.
    """
    from app.agent.llm import ChatMessage, get_provider

    override = _read_llm_override(request)
    try:
        with request_override(override):
            provider = get_provider()
            resp = await provider.chat(
                [ChatMessage(role="user", content="ping")],
                temperature=0.0,
                max_tokens=8,
            )
        return {
            "ok": True,
            "provider": override.get("provider") or None,
            "model": override.get("model") or None,
            "reply": (resp.text or "").strip()[:120],
        }
    except Exception as exc:  # network / auth / config failures
        return {
            "ok": False,
            "provider": override.get("provider") or None,
            "model": override.get("model") or None,
            "error": str(exc),
        }


@router.get("/tools")
async def list_tools(
    category: Optional[str] = None,
    _: User = Depends(get_current_user),
) -> dict[str, Any]:
    tools = [
        {
            "name": t.name,
            "description": t.description,
            "category": t.category,
            "requires_confirmation": t.requires_confirmation,
            "parameters": t.parameters,
        }
        for t in tool_registry.all()
        if category is None or t.category == category
    ]
    return {"items": tools, "count": len(tools)}


class InvokeToolRequest(BaseModel):
    name: str
    arguments: dict[str, Any] = {}
    confirmed: bool = False


@router.post("/tools/invoke")
async def invoke_tool(
    request: Request,
    body: InvokeToolRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    tool = tool_registry.get(body.name)
    if tool is None:
        raise HTTPException(status_code=404, detail=f"Unknown tool: {body.name}")
    if tool.requires_confirmation and not body.confirmed:
        return {
            "status": "pending_confirmation",
            "tool": body.name,
            "arguments": body.arguments,
            "description": tool.description,
        }
    try:
        # Bind per-request LLM credentials so vision / future LLM-using tools
        # honour the caller's settings.
        with request_override(_read_llm_override(request)):
            result = await tool_registry.invoke(
                body.name, db=db, user_id=current_user.id, **body.arguments
            )
        return {"status": "ok", "tool": body.name, "result": result}
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ----------------- v2: action audit log + undo -----------------


@router.get("/actions")
async def list_actions(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    rows = (
        await db.execute(
            select(AgentAction)
            .where(AgentAction.user_id == current_user.id)
            .order_by(desc(AgentAction.created_at))
            .limit(limit)
        )
    ).scalars().all()
    return {
        "items": [
            {
                "id": r.id,
                "action_type": r.action_type,
                "diff": r.diff,
                "status": r.status,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ],
    }


@router.post("/actions/{action_id}/undo")
async def undo(
    action_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, Any]:
    try:
        row = await undo_action(db, user_id=current_user.id, action_id=action_id)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except UndoNotSupported as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return {"status": "ok", "id": row.id, "action_type": row.action_type, "new_status": row.status}