from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import secrets
from typing import Callable


@dataclass
class VerificationCodeEntry:
    code: str
    expires_at: datetime


class VerificationCodeStore:
    def __init__(
        self,
        ttl: timedelta,
        now_provider: Callable[[], datetime] | None = None,
    ) -> None:
        self.ttl = ttl
        self._entries: dict[str, VerificationCodeEntry] = {}
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))

    def issue_code(self, phone: str, fixed_code: str | None = None) -> str:
        code = fixed_code or f"{secrets.randbelow(1_000_000):06d}"
        self._entries[phone] = VerificationCodeEntry(
            code=code,
            expires_at=self._now_provider() + self.ttl,
        )
        return code

    def verify_code(self, phone: str, code: str) -> bool:
        entry = self._entries.get(phone)
        if entry is None:
            return False

        if entry.expires_at <= self._now_provider():
            self._entries.pop(phone, None)
            return False

        if secrets.compare_digest(entry.code, code):
            self._entries.pop(phone, None)
            return True

        return False

    def peek_code(self, phone: str) -> str | None:
        entry = self._entries.get(phone)
        if entry is None:
            return None

        if entry.expires_at <= self._now_provider():
            self._entries.pop(phone, None)
            return None

        return entry.code
