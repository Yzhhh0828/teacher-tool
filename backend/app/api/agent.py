import uuid
import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.user import User
from app.api.deps import get_current_user
from app.agent.chain import AgentChain
from app.agent.session import get_session, create_session


class ChatRequest(BaseModel):
    content: str
    session_id: Optional[str] = None
    image: Optional[str] = None

router = APIRouter(prefix="/agent", tags=["agent"])


@router.post("/chat")
async def chat(
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

    # Create agent chain with db
    agent = AgentChain(session, db)

    async def event_generator():
        try:
            # Process message
            result = await agent.process(user_input, image_data)

            # Send response
            yield {
                "event": "message",
                "data": json.dumps({
                    "content": result["content"],
                    "session_id": session_id,
                    "needs_confirmation": result.get("needs_confirmation", False),
                    "action_executed": result.get("action_executed", False),
                }),
            }

            # Send done signal
            yield {"event": "done", "data": ""}

        except Exception as e:
            yield {
                "event": "error",
                "data": json.dumps({"error": str(e)}),
            }

    from sse_starlette.sse import EventSourceResponse
    return EventSourceResponse(event_generator())


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
    from app.agent.session import delete_session

    session = get_session(session_id)

    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    delete_session(session_id)
    return {"success": True}