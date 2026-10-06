from pathlib import Path
from urllib.parse import urlsplit

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    off_user_agent: str = "Unlabel/0.2.2 (https://github.com/Vaibhavsh0120/Unlabel)"
    off_timeout_seconds: float = Field(default=8, ge=1, le=15)
    off_max_response_bytes: int = Field(default=524_288, ge=1024, le=1_048_576)
    cors_origins: list[str] = Field(default_factory=list)
    catalogue_directory: str = Field(default="", max_length=1024)
    catalogue_require_receipt: bool = False

    def catalogue_path(self) -> Path | None:
        if not self.catalogue_directory.strip():
            return None
        directory = Path(self.catalogue_directory)
        if not directory.is_absolute():
            directory = Path(__file__).resolve().parents[2] / directory
        return directory.resolve()

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
