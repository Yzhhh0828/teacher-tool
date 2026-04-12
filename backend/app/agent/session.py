from datetime import datetime
from typing import Optional


class ConversationSession:
    def __init__(self, session_id: str, user_id: int, messages: list = None):
        self.session_id = session_id
        self.user_id = user_id
        self.messages = messages or []
        self.pending_action = None  # Store action waiting for confirmation

    def add_user_message(self, content: str, image_url: str = None):
        self.messages.append({
            "role": "user",
            "content": content,
            "image_url": image_url,
            "timestamp": datetime.utcnow().isoformat(),
        })

    def add_ai_message(self, content: str):
        self.messages.append({
            "role": "assistant",
            "content": content,
            "timestamp": datetime.utcnow().isoformat(),
        })

    def set_pending_action(self, action: dict):
        """Store an action waiting for user confirmation"""
        self.pending_action = action

    def clear_pending_action(self):
        self.pending_action = None

    def to_dict(self) -> dict:
        return {
            "session_id": self.session_id,
            "user_id": self.user_id,
            "messages": self.messages,
            "pending_action": self.pending_action,
        }


# In-memory session storage (use Redis in production)
_session_store: dict[str, ConversationSession] = {}


def get_session(session_id: str) -> Optional[ConversationSession]:
    return _session_store.get(session_id)


def create_session(session_id: str, user_id: int) -> ConversationSession:
    session = ConversationSession(session_id, user_id)
    _session_store[session_id] = session
    return session


def delete_session(session_id: str):
    if session_id in _session_store:
        del _session_store[session_id]