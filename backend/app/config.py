from functools import lru_cache
from typing import Any
from pydantic import computed_field, model_validator, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    APP_NAME: str = "Teacher Tool"
    APP_ENV: str = "development"
    DEBUG: bool = True
    BACKEND_CORS_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ]

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teacher_tool.db"

    # JWT
    JWT_SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    VERIFICATION_CODE_TTL_SECONDS: int = 300
    EXPOSE_DEBUG_VERIFICATION_CODE: bool = True
    DEV_FIXED_VERIFICATION_CODE: str = "123456"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # LLM
    LLM_PROVIDER: str = "openai"  # openai or anthropic
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_BASE_URL: str = "https://api.anthropic.com"

    # Storage
    STORAGE_TYPE: str = "local"  # local, minio, oss
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"
    MINIO_BUCKET: str = "teacher-tool"

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: Any) -> list[str]:
        if value is None:
            return []

        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            return [origin.strip() for origin in stripped.split(",") if origin.strip()]

        if isinstance(value, list):
            return value

        raise TypeError("BACKEND_CORS_ORIGINS must be a list or comma-separated string")

    @computed_field
    @property
    def is_production(self) -> bool:
        return self.APP_ENV.lower() == "production" or not self.DEBUG

    @computed_field
    @property
    def cors_allow_credentials(self) -> bool:
        return "*" not in self.BACKEND_CORS_ORIGINS

    @computed_field
    @property
    def should_expose_debug_verification_code(self) -> bool:
        return self.DEBUG and self.EXPOSE_DEBUG_VERIFICATION_CODE

    @model_validator(mode="after")
    def validate_environment(self) -> "Settings":
        self.validate_production_settings()
        return self

    def validate_production_settings(self):
        if self.APP_ENV.lower() == "production" and self.DEBUG:
            raise ValueError("DEBUG must be False when APP_ENV is production")
        if self.is_production and self.JWT_SECRET_KEY == "your-secret-key-change-in-production":
            raise ValueError("JWT_SECRET_KEY must be changed in production!")
        if self.is_production and "*" in self.BACKEND_CORS_ORIGINS:
            raise ValueError("BACKEND_CORS_ORIGINS cannot contain '*' in production")
        if self.is_production and self.EXPOSE_DEBUG_VERIFICATION_CODE:
            raise ValueError("EXPOSE_DEBUG_VERIFICATION_CODE must be disabled in production")


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
