import pytest
from datetime import datetime, timedelta, timezone
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
)


def test_password_hash_and_verify():
    password = "test_password_123"
    hashed = get_password_hash(password)

    assert hashed != password
    assert verify_password(password, hashed) is True
    assert verify_password("wrong_password", hashed) is False


def test_create_and_decode_access_token():
    data = {"sub": "123"}
    token = create_access_token(data)

    payload = decode_token(token)
    assert payload is not None
    assert payload["sub"] == "123"
    assert payload["type"] == "access"


def test_create_and_decode_refresh_token():
    data = {"sub": "123"}
    token = create_refresh_token(data)

    payload = decode_token(token)
    assert payload is not None
    assert payload["sub"] == "123"
    assert payload["type"] == "refresh"


def test_expired_token():
    data = {"sub": "123"}
    # Create token that expires immediately
    token = create_access_token(data, expires_delta=timedelta(seconds=-1))

    payload = decode_token(token)
    assert payload is None  # Should fail due to expiry


def test_invalid_token():
    payload = decode_token("invalid_token")
    assert payload is None
