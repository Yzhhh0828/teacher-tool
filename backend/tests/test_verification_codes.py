from datetime import UTC, datetime, timedelta

from app.core.verification_codes import VerificationCodeStore


def test_issued_code_can_be_verified_once():
    current_time = datetime(2026, 4, 13, 12, 0, tzinfo=UTC)
    store = VerificationCodeStore(
        ttl=timedelta(minutes=5),
        now_provider=lambda: current_time,
    )

    code = store.issue_code("13800138000", fixed_code="123456")

    assert code == "123456"
    assert store.verify_code("13800138000", "123456") is True
    assert store.verify_code("13800138000", "123456") is False


def test_expired_code_is_rejected_and_removed():
    current_time = datetime(2026, 4, 13, 12, 0, tzinfo=UTC)
    store = VerificationCodeStore(
        ttl=timedelta(seconds=30),
        now_provider=lambda: current_time,
    )

    store.issue_code("13800138000", fixed_code="654321")
    current_time = current_time + timedelta(minutes=1)

    assert store.verify_code("13800138000", "654321") is False
    assert store.peek_code("13800138000") is None
