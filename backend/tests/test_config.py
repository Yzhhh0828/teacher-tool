import pytest

from app.config import Settings


def test_parses_cors_origins_from_comma_separated_string():
    settings = Settings(
        DEBUG=True,
        BACKEND_CORS_ORIGINS="http://localhost:3000, http://127.0.0.1:8080",
    )

    assert settings.BACKEND_CORS_ORIGINS == [
        "http://localhost:3000",
        "http://127.0.0.1:8080",
    ]
    assert settings.cors_allow_credentials is True


def test_rejects_wildcard_cors_in_production():
    with pytest.raises(ValueError, match="BACKEND_CORS_ORIGINS"):
        Settings(
            DEBUG=False,
            JWT_SECRET_KEY="replace-me",
            EXPOSE_DEBUG_VERIFICATION_CODE=False,
            BACKEND_CORS_ORIGINS="*",
        )


def test_disables_debug_code_exposure_in_production():
    settings = Settings(
        DEBUG=False,
        JWT_SECRET_KEY="replace-me",
        EXPOSE_DEBUG_VERIFICATION_CODE=False,
        BACKEND_CORS_ORIGINS="https://teacher-tool.example.com",
    )

    assert settings.should_expose_debug_verification_code is False


def test_rejects_debug_mode_in_production_environment():
    with pytest.raises(ValueError, match="DEBUG must be False"):
        Settings(
            APP_ENV="production",
            DEBUG=True,
            JWT_SECRET_KEY="replace-me",
            EXPOSE_DEBUG_VERIFICATION_CODE=False,
            BACKEND_CORS_ORIGINS="https://teacher-tool.example.com",
        )
