"""Revocation-aware Auth adapter and owner identity admission for the API."""

import time
from uuid import UUID

import httpx
import jwt
import psycopg

from app.accounts.store import owner_hash
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.service import actor_hash
from app.community.store import StoreUnavailable
from app.selfhost.community_store import PostgresContributionStore
from app.selfhost.private_store import PostgresNotifications, PostgresPersonalStore


class IdentityRuntime:
    def __init__(self, resources):
        self.resources = resources
        self.pool = resources.pool
        self.personal_store = PostgresPersonalStore(
            self.pool,
            self.delete_identity,
            lambda uid: actor_hash(uid, resources.settings.actor_secret.get_secret_value()),
        )
        self.notification_store = PostgresNotifications(self.pool)
        if getattr(resources.settings, "community_enabled", False):
            self.store = PostgresContributionStore(self.pool)

    def _verify(self, token, *, account=False, recent=False):
        if not isinstance(token, str) or not 1 <= len(token) <= 8192:
            raise AuthenticationInvalid()
        settings = self.resources.settings
        try:
            claims = jwt.decode(
                token,
                settings.identity_jwt_secret.get_secret_value(),
                algorithms=["HS256"],
                audience="authenticated",
                issuer=settings.public_url + "/auth/v1",
                leeway=5,
                options={"require": ["exp", "iat", "sub", "aud", "iss", "session_id"]},
            )
            uid = str(UUID(claims["sub"]))
            if not isinstance(claims["session_id"], str):
                raise ValueError()
            UUID(claims["session_id"])
            if claims.get("role") != "authenticated" or (
                account and claims.get("is_anonymous") is not False
            ):
                raise ValueError()
            if recent and not any(
                method.get("method") in {"password", "oauth", "id_token", "sso/saml", "otp"}
                and isinstance(method.get("timestamp"), (int, float))
                and 0 <= time.time() - method["timestamp"] <= 305
                for method in claims.get("amr", [])
                if isinstance(method, dict)
            ):
                raise ValueError()
        except (jwt.PyJWTError, ValueError, TypeError, KeyError):
            raise AuthenticationInvalid() from None
        owner = owner_hash(uid, settings.actor_secret.get_secret_value())
        try:
            with self.pool.connection() as c:
                deleted = c.execute(
                    "SELECT 1 FROM accounts.deletion_markers WHERE owner_hash=%s", (owner,)
                ).fetchone()
        except psycopg.Error:
            raise AuthenticationUnavailable() from None
        if deleted:
            if recent:
                return uid
            raise AuthenticationInvalid()
        try:
            result = self.resources.identity.get(
                "/user", headers={"Authorization": "Bearer " + token}
            )
            if result.status_code in {401, 403, 404}:
                raise AuthenticationInvalid()
            result.raise_for_status()
            user = result.json()
            if (
                not isinstance(user, dict)
                or user.get("id") != uid
                or (account and user.get("is_anonymous") is not False)
            ):
                raise AuthenticationInvalid()
        except (httpx.HTTPError, ValueError):
            raise AuthenticationUnavailable() from None
        if account:
            try:
                with self.pool.connection() as c:
                    # Recheck under the same owner lock as deletion. A request
                    # verified upstream before deletion cannot recreate the user.
                    c.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", (owner,))
                    if c.execute(
                        "SELECT 1 FROM accounts.deletion_markers WHERE owner_hash=%s", (owner,)
                    ).fetchone():
                        if recent:
                            return uid
                        raise AuthenticationInvalid()
                    c.execute(
                        """INSERT INTO accounts.users(id,auth_subject,owner_hash) VALUES(%s,%s,%s)
                        ON CONFLICT(id) DO NOTHING""",
                        (UUID(uid), UUID(uid), owner),
                    )
            except psycopg.Error:
                raise AuthenticationUnavailable() from None
        return uid

    def verify_token(self, token):
        return self._verify(token)

    def verify_account_token(self, token):
        return self._verify(token, account=True)

    def verify_recent_account_token(self, token):
        return self._verify(token, account=True, recent=True)

    def delete_identity(self, uid):
        now = int(time.time())
        settings = self.resources.settings
        token = jwt.encode(
            {"role": "service_role", "iat": now, "exp": now + 60},
            settings.identity_jwt_secret.get_secret_value(),
            algorithm="HS256",
        )
        try:
            result = self.resources.identity.delete(
                "/admin/users/" + str(UUID(uid)), headers={"Authorization": "Bearer " + token}
            )
            if result.status_code not in {200, 204, 404}:
                raise StoreUnavailable()
        except httpx.HTTPError:
            raise StoreUnavailable() from None

    def close(self):
        self.resources.close()
