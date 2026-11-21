"""Next-major API entry point. Legacy production remains on app.main until cutover."""

import hashlib
import json
import re
from contextlib import asynccontextmanager
from typing import Annotated
from urllib.parse import urlsplit

import httpx
from fastapi import Header, Request
from fastapi.responses import JSONResponse, Response
from starlette.concurrency import run_in_threadpool

from app.accounts.store import SyncConflict, SyncDeleted, owner_hash
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings
from app.main import create_app
from app.selfhost.private_store import PostgresProfileStore
from app.selfhost.profile import ProfileSnapshot, ProfileUpdate
from app.selfhost.resources import PlatformSettings, Resources
from app.selfhost.runtime import IdentityRuntime


def safe_redirect(location, frontend_url):
    if (
        not isinstance(location, str)
        or not 1 <= len(location) <= 4096
        or any(ord(character) < 32 or ord(character) == 127 for character in location)
    ):
        return False
    try:
        destination, expected = urlsplit(location), urlsplit(frontend_url)
        return (
            destination.scheme == "https"
            and destination.netloc == expected.netloc
            and destination.username is None
            and destination.password is None
        )
    except ValueError:
        return False


def create_platform_app(settings=None, *, identity_transport=None):
    platform = settings or PlatformSettings()
    resources = Resources(platform)
    identity_runtime = IdentityRuntime(resources)
    profiles = PostgresProfileStore(resources.pool)
    config = Settings(
        _env_file=None,
        cors_origins=[platform.frontend_url],
        catalogue_directory="",
        community_enabled=getattr(platform, "community_enabled", False),
        account_sync_enabled=True,
        ai_enabled=False,
        community_actor_secret=platform.actor_secret,
    )
    config.web_push_private_key = platform.web_push_private_key
    config.web_push_public_key = platform.web_push_public_key
    application = create_app(config, data_runtime=resources, community_runtime=identity_runtime)
    previous_lifespan = application.router.lifespan_context

    @asynccontextmanager
    async def lifespan(app):
        try:
            await run_in_threadpool(resources.start)
            async with httpx.AsyncClient(
                base_url=platform.identity_url,
                timeout=httpx.Timeout(8, connect=3, pool=3),
                limits=httpx.Limits(max_connections=6, max_keepalive_connections=3),
                follow_redirects=False,
                trust_env=False,
                transport=identity_transport,
            ) as identity_client:
                app.state.identity_client = identity_client
                async with previous_lifespan(app):
                    yield
        finally:
            await run_in_threadpool(resources.close)

    application.router.lifespan_context = lifespan
    application.state.platform = resources

    def profile_owner(authorization):
        parts = authorization.split(" ") if authorization else []
        if len(parts) != 2 or parts[0].lower() != "bearer" or not 1 <= len(parts[1]) <= 8192:
            raise AuthenticationInvalid()
        uid = identity_runtime.verify_account_token(parts[1])
        return owner_hash(uid, platform.actor_secret.get_secret_value())

    def profile_failure(error):
        headers = {"Cache-Control": "no-store"}
        if isinstance(error, (AuthenticationInvalid, SyncDeleted)):
            status, code = 401, "account_authentication_required"
            headers["WWW-Authenticate"] = "Bearer"
        elif isinstance(error, SyncConflict):
            return JSONResponse(
                {
                    "schema_version": "1",
                    "code": "profile_revision_conflict",
                    "current_revision": error.revision,
                },
                status_code=409,
                headers=headers,
            )
        elif isinstance(error, StoreQuotaExceeded):
            status, code = 429, "profile_limit"
        else:
            status, code = 503, "profile_unavailable"
        return JSONResponse(
            {"schema_version": "1", "code": code}, status_code=status, headers=headers
        )

    @application.get(
        "/v1/account/profile", response_model=ProfileSnapshot, tags=["Private profile"]
    )
    def read_profile(authorization: Annotated[str | None, Header(max_length=8199)] = None):
        try:
            result = profiles.read(profile_owner(authorization))
            return JSONResponse(
                result.model_dump(mode="json"), headers={"Cache-Control": "no-store"}
            )
        except (AuthenticationInvalid, AuthenticationUnavailable, StoreUnavailable) as error:
            return profile_failure(error)

    @application.put(
        "/v1/account/profile", response_model=ProfileSnapshot, tags=["Private profile"]
    )
    def replace_profile(
        body: ProfileUpdate,
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        try:
            result = profiles.replace(profile_owner(authorization), body)
            return JSONResponse(
                result.model_dump(mode="json"), headers={"Cache-Control": "no-store"}
            )
        except (
            AuthenticationInvalid,
            AuthenticationUnavailable,
            StoreUnavailable,
            StoreQuotaExceeded,
            SyncConflict,
        ) as error:
            return profile_failure(error)

    @application.get("/health/live", include_in_schema=False)
    def live():
        return {"status": "alive"}

    @application.get("/health/dependencies", include_in_schema=False)
    def dependencies():
        try:
            resources.health()
            return {
                "status": "ready",
                "dependencies": ["postgresql", "mongodb", "redis", "identity"],
                "account_contract": "selfhost-account-v2",
            }
        except Exception:
            return JSONResponse({"status": "unavailable"}, status_code=503)

    @application.get("/v1/platform", tags=["Platform"])
    def platform_metadata():
        cutover_ready = getattr(platform, "cutover_ready", False) is True
        return {
            "release_channel": "production" if cutover_ready else "next_major_staging",
            "storage": {
                "application": "postgresql",
                "evidence": "mongodb",
                "cache": "redis",
                "jobs": "postgresql",
            },
            "cutover_ready": cutover_ready,
        }

    @application.get("/v1/platform/catalogue-summary", tags=["Platform"])
    def catalogue_summary():
        try:
            manifest = resources.catalogue.manifest
            research = resources.research.status()
            key = hashlib.sha256(
                f"catalogue-summary:{manifest.source_sha256}:{research['dataset_sha256']}".encode()
            ).hexdigest()
            value = resources.cached(key)
            if value is None:
                value = {
                    "source_sha256": manifest.source_sha256,
                    "indexed_products": manifest.indexed_products,
                    "research": research,
                }
                resources.cache_public(key, value)
            return value
        except (OSError, ValueError):
            return JSONResponse({"status": "unavailable"}, status_code=503)

    methods = {
        "health": {"GET"},
        "settings": {"GET"},
        "signup": {"POST"},
        "token": {"POST"},
        "logout": {"POST"},
        "recover": {"POST"},
        "verify": {"GET", "POST"},
        "resend": {"POST"},
        "reauthenticate": {"GET"},
        "authorize": {"GET"},
        "callback": {"GET"},
        "user": {"GET", "PUT"},
        "user/identities/authorize": {"GET"},
    }
    queries = {
        "signup": {"redirect_to"},
        "token": {"grant_type"},
        "logout": {"scope"},
        "recover": {"redirect_to"},
        "verify": {"token", "token_hash", "type", "redirect_to"},
        "resend": {"redirect_to"},
        "user": {"redirect_to"},
        "authorize": {"provider", "redirect_to", "code_challenge", "code_challenge_method", "prompt"},
        "callback": {"code", "state", "error", "error_description", "scope", "authuser", "prompt", "hd"},
        "user/identities/authorize": {
            "provider", "redirect_to", "code_challenge", "code_challenge_method", "skip_http_redirect", "prompt"
        },
    }

    @application.api_route(
        "/auth/v1/{path:path}", methods=["GET", "POST", "PUT", "DELETE"], include_in_schema=False
    )
    async def identity_proxy(path: str, request: Request):
        permitted = methods.get(path)
        if permitted is None and re.fullmatch(
            r"user/identities/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", path
        ):
            permitted = {"DELETE"}
        if permitted is None:
            return JSONResponse({"error": "not_found"}, status_code=404)
        if request.method not in permitted:
            return JSONResponse({"error": "method_not_allowed"}, status_code=405)
        params = request.query_params.multi_items()
        if (
            len(request.scope.get("query_string", b"")) > 8192
            or len({key for key, _ in params}) != len(params)
            or any(
                key not in queries.get(path, set()) or len(value) > 4096 for key, value in params
            )
            or any(
                key == "redirect_to" and not safe_redirect(value, platform.frontend_url)
                for key, value in params
            )
        ):
            return JSONResponse({"error": "invalid_query"}, status_code=422)
        if path in {"authorize", "user/identities/authorize"} and (
            request.query_params.get("provider") != "google"
            or request.query_params.get("code_challenge_method") != "s256"
            or re.fullmatch(r"[A-Za-z0-9_-]{43}", request.query_params.get("code_challenge", ""))
            is None
            or "redirect_to" not in request.query_params
        ):
            return JSONResponse({"error": "invalid_oauth_request"}, status_code=422)
        payload = await request.body()
        if len(payload) > 131072:
            return JSONResponse({"error": "request_too_large"}, status_code=413)
        authorization = request.headers.get("authorization", "")
        parts = authorization.split(" ") if authorization else []
        if authorization and (
            len(parts) != 2 or parts[0].lower() != "bearer" or not 1 <= len(parts[1]) <= 8192
        ):
            return JSONResponse({"error": "invalid_authorization"}, status_code=401)
        if payload:
            if request.method not in {"POST", "PUT"}:
                return JSONResponse({"error": "unexpected_body"}, status_code=422)
            if (
                request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
                != "application/json"
            ):
                return JSONResponse({"error": "json_required"}, status_code=415)
            try:
                body = json.loads(payload)
                if not isinstance(body, dict) or any(
                    key in body and not safe_redirect(body[key], platform.frontend_url)
                    for key in ("redirect_to", "email_redirect_to")
                ):
                    raise ValueError()
            except (ValueError, UnicodeDecodeError, RecursionError):
                return JSONResponse({"error": "invalid_body"}, status_code=422)
        headers = {"accept": "application/json", "content-type": "application/json"}
        if authorization:
            headers["authorization"] = authorization
        try:
            async with request.app.state.identity_client.stream(
                request.method,
                "/" + path,
                params=params,
                content=payload,
                headers=headers,
            ) as result:
                content = bytearray()
                async for chunk in result.aiter_bytes():
                    content.extend(chunk)
                    if len(content) > 262144:
                        return JSONResponse(
                            {"error": "identity_response_too_large"}, status_code=502
                        )
        except httpx.HTTPError:
            return JSONResponse({"error": "identity_unavailable"}, status_code=503)
        response_headers = {"Cache-Control": "no-store"}
        if "location" in result.headers:
            location = result.headers["location"]
            google_redirect = False
            if path in {"authorize", "user/identities/authorize"} and len(location) <= 8192:
                try:
                    provider = urlsplit(location)
                    google_redirect = (
                        provider.scheme == "https"
                        and provider.netloc == "accounts.google.com"
                        and provider.path in {"/o/oauth2/v2/auth", "/o/oauth2/auth"}
                        and not any(ord(c) < 32 or ord(c) == 127 for c in location)
                    )
                except ValueError:
                    pass
            if not google_redirect and not safe_redirect(location, platform.frontend_url):
                return JSONResponse({"error": "invalid_redirect"}, status_code=502)
            response_headers["Location"] = location
        return Response(
            bytes(content),
            status_code=result.status_code,
            media_type=result.headers.get("content-type", "application/json").split(";")[0],
            headers=response_headers,
        )

    return application
