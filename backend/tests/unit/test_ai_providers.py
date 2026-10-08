"""Vision adapters never route tasks or expose provider bodies/credentials."""

import asyncio
import json
from datetime import UTC, datetime, timedelta
from email.utils import format_datetime

import httpx
import pytest
from pydantic import SecretStr, ValidationError

from app.ai import providers
from app.ai.models import ExtractionRequest
from app.ai.providers import Credential, ProviderFailure, extract
from tests.unit.test_ai_models import extracted_dict, image_dict

SECRET = "synthetic-private-provider-key"


def credential(provider="gemini", **changes):
    return Credential(
        **{
            "id": provider + "-primary",
            "provider": provider,
            "api_key": SecretStr(SECRET),
            "model": "gemini-3.5-flash-lite" if provider == "gemini" else "gpt-4.1-mini",
            **changes,
        }
    )


def request():
    return ExtractionRequest.model_validate({"images": [image_dict()], "privacy_consent": True})


def envelope(provider="gemini", data=None):
    text = json.dumps(extracted_dict() if data is None else data)
    if provider == "gemini":
        return {"candidates": [{"finishReason": "STOP", "content": {"parts": [{"text": text}]}}]}
    return {
        "status": "completed",
        "output": [
            {
                "type": "message",
                "role": "assistant",
                "status": "completed",
                "content": [{"type": "output_text", "text": text}],
            }
        ],
    }


def test_credential_repr_omits_secret_and_frozen_fields_prevent_rerouting():
    active = credential()
    assert SECRET not in repr(active)
    with pytest.raises(AttributeError):
        active.provider = "openai"  # pyright: ignore[reportAttributeAccessIssue]


@pytest.mark.parametrize(
    "changes",
    [
        {"id": "../caller-controlled"},
        {"model": "model:generateContent?key=evil"},
        {"model": "https://unexpected.test/model"},
        {"provider": "caller-controlled"},
        {"api_key": SecretStr("short")},
        {"api_key": SecretStr("private-key\nheader-injection")},
        {"api_key": SECRET},
    ],
)
def test_invalid_credential_configuration_does_not_echo_values(changes):
    with pytest.raises(ValueError) as caught:
        credential(**changes)
    assert SECRET not in str(caught.value)
    assert "evil" not in str(caught.value)


@pytest.mark.asyncio
@pytest.mark.parametrize("provider", ["gemini", "openai"])
async def test_only_selected_fixed_origin_is_called_once_with_bounded_structured_output(provider):
    requests = []

    def respond(incoming):
        requests.append(incoming)
        assert incoming.method == "POST"
        assert incoming.url.scheme == "https"
        assert incoming.url.host == (
            "generativelanguage.googleapis.com" if provider == "gemini" else "api.openai.com"
        )
        assert not incoming.url.query
        assert SECRET not in str(incoming.url)
        assert incoming.headers["Accept-Encoding"] == "identity"
        payload = json.loads(incoming.content)
        if provider == "gemini":
            assert incoming.headers["x-goog-api-key"] == SECRET
            assert payload["contents"][0]["parts"][2]["inlineData"]["mimeType"] == "image/png"
            config = payload["generationConfig"]
            assert config["maxOutputTokens"] == 8192
            assert config["responseMimeType"] == "application/json"
            assert config["responseSchema"]["type"] == "OBJECT"
            identity = config["responseSchema"]["properties"]["identity"]
            assert identity["properties"]["name"]["nullable"] is True
        else:
            assert incoming.headers["Authorization"] == "Bearer " + SECRET
            assert payload["store"] is False
            assert payload["max_output_tokens"] == 8192
            assert payload["input"][0]["content"][2]["image_url"].startswith(
                "data:image/png;base64,"
            )
            output_format = payload["text"]["format"]
            assert output_format["strict"] is True
            assert output_format["type"] == "json_schema"
            for definition in [output_format["schema"], *output_format["schema"]["$defs"].values()]:
                assert definition["additionalProperties"] is False
                assert set(definition["required"]) == set(definition["properties"])
        return httpx.Response(200, json=envelope(provider))

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond), trust_env=False) as client:
        label = await extract(client, credential(provider), request())
    assert label.identity.barcode == "8901764051258"
    assert label.evidence == "machine_extracted_unverified"
    assert len(requests) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "status,expected_kind,cooldown",
    [
        (401, "credential", 86400),
        (403, "credential", 86400),
        (429, "quota", 7200),
        (502, "transient", 30),
        (408, "transient", 30),
        (400, "invalid_response", 30),
        (404, "invalid_response", 30),
        (301, "invalid_response", 30),
    ],
)
async def test_http_failure_classification_never_follows_redirect_or_echoes_body(
    status, expected_kind, cooldown
):
    calls = []

    def respond(incoming):
        calls.append(incoming)
        return httpx.Response(
            status,
            text=SECRET + " private photo OCR",
            headers={"Retry-After": "7200", "Location": "https://unexpected.test/"},
        )

    async with httpx.AsyncClient(
        transport=httpx.MockTransport(respond), follow_redirects=True
    ) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == expected_kind
    assert caught.value.status == status
    assert caught.value.cooldown_seconds == cooldown
    assert SECRET not in str(caught.value)
    assert "OCR" not in str(caught.value)
    assert len(calls) == 1


def test_provider_retry_after_dates_and_bounds_respect_cooldowns():
    future = format_datetime(datetime.now(UTC) + timedelta(hours=2))
    assert 7198 <= providers._retry_after(future) <= 7200
    assert providers._retry_after("9999999999") == 86400
    assert providers._retry_after("invalid-private-error") == 60
    assert providers._retry_after(None) == 60
    assert providers._retry_after("0") == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "reason,expected_kind",
    [("API_KEY_INVALID", "credential"), ("INVALID_ARGUMENT", "invalid_response")],
)
async def test_gemini_documented_http400_invalid_key_can_fail_over_without_rotating_bad_requests(
    reason, expected_kind
):
    body = {
        "error": {
            "message": SECRET,
            "details": [
                {
                    "@type": "type.googleapis.com/google.rpc.ErrorInfo",
                    "domain": "googleapis.com",
                    "reason": reason,
                }
            ],
        }
    }
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _: httpx.Response(400, json=body))
    ) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == expected_kind
    assert SECRET not in str(caught.value)


@pytest.mark.asyncio
async def test_large_invalid_error_body_is_not_parsed_or_retained():
    stream = ChunkStream([b"x" * 8193])
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _: httpx.Response(400, stream=stream))
    ) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == "invalid_response"
    assert stream.closed


def test_gemini_grammar_omits_measured_incompatible_bounds_but_keeps_structure():
    schema = providers._json_schema()
    grammar = providers._gemini_schema(schema, schema["$defs"])

    def check(value):
        if isinstance(value, dict):
            assert not set(value) & {
                "minItems",
                "maxItems",
                "minimum",
                "maximum",
                "exclusiveMinimum",
            }
            for item in value.values():
                check(item)
        elif isinstance(value, list):
            for item in value:
                check(item)

    check(grammar)
    assert grammar["properties"]["regions"]["items"]["properties"]["label"]["enum"]
    assert schema["properties"]["regions"]["maxItems"] == 160
    assert schema["$defs"]["NormalizedBox"]["properties"]["top"]["maximum"] == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "error,expected_kind",
    [
        (httpx.ConnectError("private url " + SECRET), "transient"),
        (httpx.ReadTimeout("private " + SECRET), "transient"),
        (httpx.PoolTimeout("local " + SECRET), "busy"),
    ],
)
async def test_transport_errors_are_sanitized_and_local_pool_overload_cannot_rotate_keys(
    error, expected_kind
):
    def fail(_):
        raise error

    async with httpx.AsyncClient(transport=httpx.MockTransport(fail)) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == expected_kind
    assert SECRET not in str(caught.value)
    if expected_kind == "busy":
        assert caught.value.cooldown_seconds == 2


@pytest.mark.asyncio
async def test_overall_timeout_bounds_slow_provider_and_preserves_external_cancellation(
    monkeypatch,
):
    monkeypatch.setattr(providers, "TOTAL_TIMEOUT_SECONDS", 0.01)

    async def slow(_):
        await asyncio.sleep(10)
        return httpx.Response(200, json=envelope())

    async with httpx.AsyncClient(transport=httpx.MockTransport(slow)) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == "transient"

    async def cancelled(_):
        raise asyncio.CancelledError()

    async with httpx.AsyncClient(transport=httpx.MockTransport(cancelled)) as client:
        with pytest.raises(asyncio.CancelledError):
            await extract(client, credential(), request())


class ChunkStream(httpx.AsyncByteStream):
    def __init__(self, chunks):
        self.chunks = chunks
        self.closed = False

    async def __aiter__(self):
        for chunk in self.chunks:
            yield chunk

    async def aclose(self):
        self.closed = True


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "response_case",
    ["declared_oversize", "negative_length", "malformed_length", "chunked_oversize", "compressed"],
)
async def test_actual_stream_and_declared_size_are_bounded_and_stream_is_closed(response_case):
    headers = {}
    chunks = [b"{}"]
    if response_case == "declared_oversize":
        headers["Content-Length"] = str(providers.MAX_RESPONSE_BYTES + 1)
    elif response_case == "negative_length":
        headers["Content-Length"] = "-1"
    elif response_case == "malformed_length":
        headers["Content-Length"] = "secret-not-a-number"
    elif response_case == "compressed":
        headers["Content-Encoding"] = "gzip"
    else:
        chunks = [b"x" * (providers.MAX_RESPONSE_BYTES // 2)] * 3
    stream = ChunkStream(chunks)

    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _: httpx.Response(200, headers=headers, stream=stream))
    ) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == "invalid_response"
    assert stream.closed


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "mutate",
    [
        lambda body: body.update(candidates=[]),
        lambda body: body.update(promptFeedback={"blockReason": "SAFETY"}),
        lambda body: body["candidates"][0].update(finishReason="MAX_TOKENS"),
        lambda body: body["candidates"][0].update(finishReason="SAFETY"),
        lambda body: body["candidates"][0]["content"]["parts"].append({"text": "ambiguous"}),
        lambda body: body["candidates"][0]["content"]["parts"][0].update(text="```json\n{}\n```"),
        lambda body: body["candidates"][0]["content"]["parts"][0].update(
            text='{"identity":null,"identity":null}'
        ),
        lambda body: body["candidates"][0]["content"]["parts"][0].update(text='{"amount":NaN}'),
        lambda body: body["candidates"][0]["content"]["parts"][0].update(
            text='{"amount":0.123456789012345678901}'
        ),
        lambda body: body["candidates"][0]["content"]["parts"][0].update(
            text="x" * (providers.MAX_EXTRACTED_JSON_BYTES + 1)
        ),
    ],
)
async def test_gemini_incomplete_refused_ambiguous_or_invalid_json_never_becomes_facts(mutate):
    body = envelope()
    mutate(body)
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _: httpx.Response(200, json=body))
    ) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), request())
    assert caught.value.kind == "invalid_response"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "mutate",
    [
        lambda body: body.update(status="incomplete"),
        lambda body: body.update(incomplete_details={"reason": "max_output_tokens"}),
        lambda body: body.update(error={"message": SECRET}),
        lambda body: body.update(output=[]),
        lambda body: body["output"][0].update(status="in_progress"),
        lambda body: body["output"][0]["content"][0].update(type="refusal", refusal=SECRET),
        lambda body: body["output"].append(body["output"][0]),
    ],
)
async def test_openai_refusals_and_truncation_are_sanitized_without_key_failover(mutate):
    body = envelope("openai")
    mutate(body)
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _: httpx.Response(200, json=body))
    ) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential("openai"), request())
    assert caught.value.kind == "invalid_response"
    assert SECRET not in str(caught.value)


@pytest.mark.asyncio
async def test_unknown_photo_highlight_and_bad_check_digit_are_rejected():
    for change in ("slot", "barcode"):
        data = extracted_dict()
        if change == "slot":
            data["regions"][0]["slot"] = "front"
        else:
            data["identity"]["barcode"] = "8901764051259"
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _, data=data: httpx.Response(200, json=envelope(data=data))
            )
        ) as client:
            with pytest.raises(ProviderFailure) as caught:
                await extract(client, credential(), request())
        assert caught.value.kind == "invalid_response"


@pytest.mark.asyncio
async def test_mutated_input_container_is_revalidated_before_network():
    photo_request = request()
    photo_request.images.append(photo_request.images[0])

    def forbidden(_):
        pytest.fail("Invalid mutated request reached a provider")

    async with httpx.AsyncClient(transport=httpx.MockTransport(forbidden)) as client:
        with pytest.raises(ProviderFailure) as caught:
            await extract(client, credential(), photo_request)
    assert caught.value.kind == "invalid_response"


def test_direct_validation_exception_strings_hide_private_photo_payloads():
    private = "private-base64-payload-that-must-not-appear"
    with pytest.raises(ValidationError) as caught:
        ExtractionRequest.model_validate(
            {"images": [{**image_dict(), "data_base64": private}], "privacy_consent": True}
        )
    assert private not in str(caught.value)
