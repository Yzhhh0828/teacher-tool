from functools import lru_cache
from pydantic import computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    # App
    APP_NAME: str = "Teacher Tool"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teacher_tool.db"

    # JWT
    JWT_SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

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

    @computed_field
    @property
    def is_production(self) -> bool:
        return not self.DEBUG

    def validate_production_settings(self):
        if self.is_production and self.JWT_SECRET_KEY == "your-secret-key-change-in-production":
            raise ValueError("JWT_SECRET_KEY must be changed in production!")


@lru_cache()
def get_settings() -> Settings:
    settings = Settings()
    settings.validate_production_settings()
    return settings


settings = get_settings()
