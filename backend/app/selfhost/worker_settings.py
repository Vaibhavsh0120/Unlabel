"""Service-scoped configuration; workers never need identity or source-store keys."""

import socket

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class SchedulerSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="UNLABEL_", extra="ignore", hide_input_in_errors=True
    )
    database_url: SecretStr
    process_instance: str = Field(
        default_factory=socket.gethostname, pattern=r"^[A-Za-z0-9_.-]{1,128}$"
    )


class NotificationWorkerSettings(SchedulerSettings):
    web_push_private_key: SecretStr = Field(min_length=20, max_length=4096)
