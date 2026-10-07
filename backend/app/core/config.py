import os
from pathlib import Path
from typing import Any, Literal
from urllib.parse import urlsplit

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic_settings.sources import ENV_FILE_SENTINEL, DotenvType


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    off_user_agent: str = "Unlabel/0.6.0 (https://github.com/Vaibhavsh0120/Unlabel)"
    off_timeout_seconds: float = Field(default=8, ge=1, le=15)
    off_max_response_bytes: int = Field(default=524_288, ge=1024, le=1_048_576)
    cors_origins: list[str] = Field(default_factory=list)
    catalogue_directory: str = Field(default="", max_length=1024)
    catalogue_require_receipt: bool = False
    claims_knowledge_directory: str = Field(default="", max_length=1024)
    community_enabled: bool = False
    community_project_id: str = Field(
        default="", max_length=30, pattern=r"^(?:[a-z][a-z0-9-]{4,28}[a-z0-9])?$"
    )
    community_database_id: Literal["unlabel"] = "unlabel"
    community_service_account_json: SecretStr | None = Field(default=None, repr=False)
    community_actor_secret: SecretStr | None = Field(default=None, repr=False)

    def __init__(self, _env_file: DotenvType | None = ENV_FILE_SENTINEL, **values: Any) -> None:
        # Preserve BaseSettings' supported dotenv override in its typed signature.
        super().__init__(_env_file=_env_file, **values)

    def claims_knowledge_path(self) -> Path:
        backend = Path(__file__).resolve().parents[2]
        if self.claims_knowledge_directory.strip():
            path = Path(self.claims_knowledge_directory)
            return path if path.is_absolute() else backend / path
        packaged = backend / "app/claims/data"
        # An invalid existing deployment bundle must not fall back to source.
        return (
            packaged
            if packaged.exists() or os.environ.get("VERCEL") == "1"
            else backend.parent / "knowledge"
        )

    def catalogue_path(self) -> Path | None:
        if not self.catalogue_directory.strip():
            return None
        directory = Path(self.catalogue_directory)
        if not directory.is_absolute():
            directory = Path(__file__).resolve().parents[2] / directory
        return directory.resolve()

    def community_configured(self) -> bool:
        return bool(
            self.community_enabled
            and self.community_project_id
            and self.community_service_account_json is not None
            and self.community_actor_secret is not None
        )

    @field_validator("community_service_account_json")
    @classmethod
    def bounded_service_account(cls, value: SecretStr | None) -> SecretStr | None:
        if value is not None and not 1 <= len(value.get_secret_value().encode("utf-8")) <= 32768:
            raise ValueError("Community credential must be bounded")
        return value

    @field_validator("community_actor_secret")
    @classmethod
    def bounded_actor_secret(cls, value: SecretStr | None) -> SecretStr | None:
        if value is not None and not 32 <= len(value.get_secret_value()) <= 1024:
            raise ValueError("Community ownership secret must contain 32–1024 characters")
        return value

    @field_validator("off_user_agent")
    @classmethod
    def valid_identity(cls, value: str) -> str:
        if not 10 <= len(value) <= 200 or any(ord(c) < 32 or ord(c) > 126 for c in value):
            raise ValueError("OFF_USER_AGENT must be a bounded printable application identity")
        return value

    @field_validator("cors_origins")
    @classmethod
    def exact_origins(cls, values: list[str]) -> list[str]:
        for value in values:
            parsed = urlsplit(value)
            # Accessing port also rejects invalid/non-numeric ports.
            _ = parsed.port
            if (
                parsed.scheme not in {"http", "https"}
                or not parsed.hostname
                or parsed.username
                or parsed.password
                or parsed.path
                or parsed.query
                or parsed.fragment
                or "*" in value
                or any(c.isspace() for c in value)
            ):
                raise ValueError("CORS_ORIGINS must contain exact HTTP(S) origins without paths")
        return values
