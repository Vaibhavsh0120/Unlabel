import json
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest


def test_runtime_requires_explicit_matching_service_account(monkeypatch):
    from app.community.auth import AuthenticationUnavailable, create_runtime

    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST", raising=False)
    monkeypatch.delenv("FIREBASE_AUTH_EMULATOR_HOST", raising=False)
    for document in ("", "{}", '{"project_id":"another","type":"service_account"}'):
        with pytest.raises(AuthenticationUnavailable) as caught:
            create_runtime("unlabel-india-catalogue", "unlabel", document)
        assert "another" not in str(caught.value)


@pytest.mark.parametrize("name", ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"])
def test_runtime_refuses_emulator_environment(monkeypatch, name):
    from app.community.auth import AuthenticationUnavailable, create_runtime

    monkeypatch.setenv(name, "localhost:8080")
    with pytest.raises(AuthenticationUnavailable):
        create_runtime("unlabel-india-catalogue", "unlabel", "{}")


def runtime_with_verifier(monkeypatch, verifier):
    from firebase_admin import auth

    from app.community.auth import CommunityRuntime

    monkeypatch.setattr(auth, "verify_id_token", verifier)
    return CommunityRuntime(SimpleNamespace(), SimpleNamespace(), "unlabel-india-catalogue")


def claims():
    return {
        "uid": "private-subject",
        "sub": "private-subject",
        "aud": "unlabel-india-catalogue",
        "iss": "https://securetoken.google.com/unlabel-india-catalogue",
        "exp": (datetime.now(UTC) + timedelta(hours=1)).timestamp(),
        "firebase": {"sign_in_provider": "anonymous"},
    }


@pytest.mark.parametrize("provider", ["anonymous", "password", "google.com"])
def test_verification_requires_revocation_check_and_returns_only_uid(monkeypatch, provider):
    def verify(token, *, app, check_revoked, clock_skew_seconds):
        assert token == "opaque-token"
        assert app is not None
        assert check_revoked is True
        assert clock_skew_seconds == 0
        return claims() | {"firebase": {"sign_in_provider": provider}}

    runtime = runtime_with_verifier(monkeypatch, verify)
    assert runtime.verify_token("opaque-token") == "private-subject"


@pytest.mark.parametrize(
    "change",
    [
        {"aud": "other"},
        {"iss": "https://securetoken.google.com/other"},
        {"sub": "different"},
        {"uid": ""},
        {"exp": 1},
        {"exp": True},
        {"firebase": {"sign_in_provider": "custom"}},
    ],
)
@pytest.mark.parametrize("provider", ["anonymous", "password", "google.com"])
def test_claims_with_wrong_project_subject_or_expiry_are_invalid(monkeypatch, change, provider):
    from app.community.auth import AuthenticationInvalid

    decoded = claims() | {"firebase": {"sign_in_provider": provider}} | change
    runtime = runtime_with_verifier(monkeypatch, lambda *args, **kwargs: decoded)
    with pytest.raises(AuthenticationInvalid):
        runtime.verify_token("opaque-token")


@pytest.mark.parametrize("value", ["", "a" * 8193, "token\nsecret", None])
def test_bounded_token_input_is_rejected_before_verification(monkeypatch, value):
    from app.community.auth import AuthenticationInvalid

    def no_call(*args, **kwargs):
        pytest.fail("Invalid token input reached verification")

    runtime = runtime_with_verifier(monkeypatch, no_call)
    with pytest.raises(AuthenticationInvalid):
        runtime.verify_token(value)


@pytest.mark.parametrize("provider", ["password", "google.com"])
def test_signed_in_scanner_can_contribute_and_sync_but_anonymous_cannot_sync(monkeypatch, provider):
    from app.community.auth import AuthenticationInvalid

    decoded = claims()
    runtime = runtime_with_verifier(monkeypatch, lambda *args, **kwargs: decoded)
    assert runtime.verify_token("opaque-token") == "private-subject"
    with pytest.raises(AuthenticationInvalid):
        runtime.verify_account_token("opaque-token")
    decoded["firebase"]["sign_in_provider"] = provider
    assert runtime.verify_token("opaque-token") == "private-subject"
    assert runtime.verify_account_token("opaque-token") == "private-subject"


@pytest.mark.parametrize(
    "change",
    [
        {"aud": "other"},
        {"iss": "https://securetoken.google.com/other"},
        {"sub": "different"},
        {"exp": 1},
        {"exp": True},
        {"firebase": {"sign_in_provider": "custom"}},
        {"firebase": {"sign_in_provider": "anonymous"}},
    ],
)
@pytest.mark.parametrize("provider", ["password", "google.com"])
def test_private_account_verification_preserves_project_subject_and_expiry_boundaries(
    monkeypatch, change, provider
):
    from app.community.auth import AuthenticationInvalid

    decoded = claims() | {"firebase": {"sign_in_provider": provider}} | change
    runtime = runtime_with_verifier(monkeypatch, lambda *args, **kwargs: decoded)
    with pytest.raises(AuthenticationInvalid):
        runtime.verify_account_token("opaque-token")


def test_google_profile_and_linked_provider_email_never_replace_uid_ownership(monkeypatch):
    decoded = claims() | {
        "email": "synthetic@example.invalid",
        "name": "Synthetic Person",
        "picture": "https://example.invalid/synthetic-avatar.png",
        "firebase": {
            "sign_in_provider": "google.com",
            "identities": {
                "google.com": ["synthetic-google-id"],
                "email": ["synthetic@example.invalid"],
            },
        },
    }
    runtime = runtime_with_verifier(monkeypatch, lambda *args, **kwargs: decoded)
    assert runtime.verify_account_token("opaque-token") == "private-subject"
    decoded["firebase"]["sign_in_provider"] = "password"
    assert runtime.verify_account_token("opaque-token") == "private-subject"


def test_private_account_verification_is_revocation_aware(monkeypatch):
    from firebase_admin import auth

    from app.community.auth import AuthenticationInvalid

    def verify(token, *, app, check_revoked, clock_skew_seconds):
        assert check_revoked is True and clock_skew_seconds == 0
        raise auth.RevokedIdTokenError("PRIVATE-PROVIDER-TEXT")

    runtime = runtime_with_verifier(monkeypatch, verify)
    with pytest.raises(AuthenticationInvalid) as error:
        runtime.verify_account_token("opaque-token")
    assert "PRIVATE" not in str(error.value)


def test_invalid_vs_transient_verification_errors_are_safe(monkeypatch):
    from firebase_admin import auth

    from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable

    for error, expected in (
        (auth.InvalidIdTokenError("SECRET token"), AuthenticationInvalid),
        (auth.RevokedIdTokenError("SECRET revoked"), AuthenticationInvalid),
        (auth.UserDisabledError("SECRET disabled"), AuthenticationInvalid),
        (
            auth.CertificateFetchError("SECRET certificate", RuntimeError("SECRET")),
            AuthenticationUnavailable,
        ),
        (RuntimeError("SECRET provider"), AuthenticationUnavailable),
    ):

        def verify(*args, failure=error, **kwargs):
            raise failure

        runtime = runtime_with_verifier(monkeypatch, verify)
        with pytest.raises(expected) as caught:
            runtime.verify_token("opaque-token")
        assert "SECRET" not in str(caught.value)


def test_runtime_passes_explicit_named_database_and_closes(monkeypatch):
    import firebase_admin
    from firebase_admin import credentials, firestore

    from app.community.auth import create_runtime

    for name in ("FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"):
        monkeypatch.delenv(name, raising=False)
    closed = []
    application = SimpleNamespace()
    database = SimpleNamespace(close=lambda: closed.append("database"))
    account = {"type": "service_account", "project_id": "unlabel-india-catalogue"}

    def certificate(value):
        assert value == account
        return "explicit-certificate"

    def initialize(credential, options, name):
        assert credential == "explicit-certificate"
        assert options == {"projectId": "unlabel-india-catalogue", "httpTimeout": 5}
        assert name.startswith("unlabel-community-")
        return application

    def client(*, app, database_id):
        assert app is application
        assert database_id == "unlabel"
        return database

    monkeypatch.setattr(credentials, "Certificate", certificate)
    monkeypatch.setattr(firebase_admin, "initialize_app", initialize)
    monkeypatch.setattr(firestore, "client", client)
    monkeypatch.setattr(firebase_admin, "delete_app", lambda app: closed.append("application"))
    runtime = create_runtime("unlabel-india-catalogue", "unlabel", json.dumps(account))
    runtime.close()
    runtime.close()
    assert closed == ["database", "application"]


def test_unknown_verifier_result_becomes_safe_unavailable(monkeypatch):
    from app.community.auth import AuthenticationUnavailable

    runtime = runtime_with_verifier(monkeypatch, lambda *args, **kwargs: None)
    with pytest.raises(AuthenticationUnavailable):
        runtime.verify_token("opaque-token")
