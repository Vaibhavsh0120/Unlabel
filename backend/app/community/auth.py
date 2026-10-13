"""Explicit credentials and revocation-aware scanner authentication."""

import json
import math
import os
import re
import time
from typing import Any
from uuid import uuid4


class AuthenticationInvalid(Exception):
    def __init__(self) -> None:
        super().__init__("A valid Firebase scanner identity is required")


class AuthenticationUnavailable(Exception):
    def __init__(self) -> None:
        super().__init__("Community authentication is unavailable")


class CommunityRuntime:
    def __init__(self, application: Any, database: Any, project_id: str) -> None:
        from app.accounts.store import FirestorePersonalStore
        from app.ai.store import FirestoreAiSelectionStore
        from app.community.store import FirestoreContributionStore

        self._application = application
        self._database = database
        self._project_id = project_id
        self._closed = False
        self.store = FirestoreContributionStore(database)
        self.personal_store = FirestorePersonalStore(database)
        self.ai_store = FirestoreAiSelectionStore(database)

    def verify_token(self, token: str) -> str:
        return self._verify_token(token, account=False)

    def verify_account_token(self, token: str) -> str:
        return self._verify_token(token, account=True)

    def _verify_token(self, token: str, *, account: bool) -> str:
        from firebase_admin import auth

        if (
            not isinstance(token, str)
            or not 1 <= len(token) <= 8192
            or any(ord(character) < 33 or ord(character) > 126 for character in token)
        ):
            raise AuthenticationInvalid()
        if self._closed:
            raise AuthenticationUnavailable()
        try:
            decoded = auth.verify_id_token(
                token, app=self._application, check_revoked=True, clock_skew_seconds=0
            )
        except (auth.InvalidIdTokenError, auth.UserDisabledError, ValueError):
            raise AuthenticationInvalid() from None
        except Exception:
            raise AuthenticationUnavailable() from None
        if not isinstance(decoded, dict):
            raise AuthenticationUnavailable()
        subject = decoded.get("uid")
        expiry = decoded.get("exp")
        if (
            decoded.get("aud") != self._project_id
            or decoded.get("iss") != f"https://securetoken.google.com/{self._project_id}"
            or not isinstance(subject, str)
            or not 1 <= len(subject) <= 128
            or decoded.get("sub") != subject
            or any(ord(character) < 32 for character in subject)
            or isinstance(expiry, bool)
            or not isinstance(expiry, (int, float))
            or not math.isfinite(expiry)
            or expiry <= time.time()
            or not isinstance(decoded.get("firebase"), dict)
            or decoded["firebase"].get("sign_in_provider")
            not in (
                {"password", "google.com"} if account else {"anonymous", "password", "google.com"}
            )
        ):
            raise AuthenticationInvalid()
        return subject

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        import firebase_admin

        try:
            self._database.close()
        finally:
            firebase_admin.delete_app(self._application)


def create_runtime(
    project_id: str, database_id: str, service_account_json: str
) -> CommunityRuntime:
    """Never consult ADC, credential files or auth/storage emulator shortcuts."""
    if (
        not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", project_id)
        or database_id != "unlabel"
        or os.environ.get("FIREBASE_AUTH_EMULATOR_HOST")
        or os.environ.get("FIRESTORE_EMULATOR_HOST")
        or not isinstance(service_account_json, str)
        or not 1 <= len(service_account_json.encode("utf-8")) <= 32768
    ):
        raise AuthenticationUnavailable()
    application = None
    database = None
    try:
        account = json.loads(service_account_json)
        if (
            not isinstance(account, dict)
            or account.get("type") != "service_account"
            or account.get("project_id") != project_id
        ):
            raise AuthenticationUnavailable()
        import firebase_admin
        from firebase_admin import credentials, firestore

        certificate = credentials.Certificate(account)
        application = firebase_admin.initialize_app(
            certificate,
            options={"projectId": project_id, "httpTimeout": 5},
            name=f"unlabel-community-{uuid4().hex}",
        )
        database = firestore.client(app=application, database_id=database_id)
        return CommunityRuntime(application, database, project_id)
    except Exception:
        if database is not None:
            try:
                database.close()
            except Exception:
                pass
        if application is not None:
            try:
                import firebase_admin

                firebase_admin.delete_app(application)
            except Exception:
                pass
        raise AuthenticationUnavailable() from None
