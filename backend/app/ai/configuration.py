"""Bounded secret configuration; callers cannot pick a provider or supply keys."""

import hashlib
import json
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator

from app.ai.providers import Credential
from app.core.config import Settings


class Replacement(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    id: str = Field(pattern=r"^[a-z][a-z0-9-]{0,47}$")
    provider: Literal["gemini", "openai"]
    api_key: SecretStr = Field(repr=False)
    model: str = Field(pattern=r"^[a-zA-Z0-9._-]{1,80}$")

    @field_validator("api_key")
    @classmethod
    def key(cls, value: SecretStr) -> SecretStr:
        key = value.get_secret_value()
        if not 16 <= len(key) <= 512 or any(ord(c) < 33 or ord(c) > 126 for c in key):
            raise ValueError("Invalid AI credential")
        return value


def credentials(config: Settings) -> tuple[Credential, ...]:
    result: list[Credential] = []
    if config.gemini_api_key is not None:
        result.append(Credential(
            id="gemini-primary", provider="gemini", api_key=config.gemini_api_key,
            model=config.gemini_model,
        ))
    if config.openai_api_key is not None:
        result.append(Credential(
            id="openai-primary", provider="openai", api_key=config.openai_api_key,
            model=config.openai_model,
        ))
    try:
        if config.ai_fallback_credentials_json is not None:
            data = json.loads(config.ai_fallback_credentials_json.get_secret_value())
            if not isinstance(data, list) or len(data) > 6:
                raise ValueError()
            for raw in data:
                value = Replacement.model_validate(raw)
                result.append(Credential(
                    id=value.id, provider=value.provider, api_key=value.api_key, model=value.model,
                ))
        if len({item.id for item in result}) != len(result):
            raise ValueError()
        if len({(item.provider, item.api_key.get_secret_value()) for item in result}) != len(result):
            raise ValueError()
    except (TypeError, ValueError):
        raise ValueError("Invalid AI replacement configuration") from None
    return tuple(result)


def configuration_digest(values: tuple[Credential, ...]) -> str:
    # Shared state stores only this digest. Rotating/removing/adding a key requires
    # a deliberate activation, preventing a rolling worker from resetting policy.
    payload = [
        [value.id, value.provider, value.model, value.api_key.get_secret_value()]
        for value in values
    ]
    return hashlib.sha256(json.dumps(payload, separators=(",", ":")).encode()).hexdigest()
