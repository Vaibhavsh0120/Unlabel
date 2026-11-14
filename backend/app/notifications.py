"""Public inbox updates and opt-in browser push, without personal scan data."""

import base64
import hashlib
import hmac
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from typing import Annotated, Literal
from urllib.parse import urlsplit

import requests
from fastapi import APIRouter, Header, HTTPException, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pywebpush import WebPushException, webpush

from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.service import actor_hash
from app.community.store import (
    FirestoreContributionStore,
    StoreQuotaExceeded,
    StoreUnavailable,
)
from app.core.config import Settings

MAX_SUBSCRIPTIONS = 128
REMINDER = {"title": "Take a closer look at a label", "body":
            "Compare the stated amounts and check the ingredients on your next package.",
            "id": "daily-label-reminder", "destination": "scan"}


class Announcement(BaseModel):
    id: str = Field(max_length=80)
    title: str = Field(max_length=100)
    body: str = Field(max_length=360)
    published_at: datetime
    destination: Literal["profile", "insights", "scan"]


class NotificationFeed(BaseModel):
    schema_version: Literal["1"] = "1"
    items: list[Announcement] = Field(max_length=20)


FEED = NotificationFeed(items=[Announcement(
    id="unlabel-0-12-notifications",
    title="Your notification inbox is ready",
    body="Find app updates here. You can also turn on an optional daily label-reading reminder.",
    published_at=datetime(2026, 11, 14, tzinfo=UTC), destination="profile",
)])


def validate_endpoint(value: str) -> str:
    parsed = urlsplit(value)
    host = parsed.hostname or ""
    if (parsed.scheme != "https" or parsed.port not in (None, 443)
        or parsed.username or parsed.password or parsed.fragment
        or not parsed.path or parsed.path == "/"
        or not (host in {"fcm.googleapis.com", "updates.push.services.mozilla.com",
                             "web.push.apple.com"}
                or host.endswith(".push.apple.com") or host.endswith(".notify.windows.com"))):
        raise ValueError("Unsupported browser push endpoint")
    return value


class PushKeys(BaseModel):
    model_config = ConfigDict(extra="forbid")
    p256dh: str = Field(min_length=86, max_length=88, pattern=r"^[A-Za-z0-9_-]+={0,2}$")
    auth: str = Field(min_length=22, max_length=24, pattern=r"^[A-Za-z0-9_-]+={0,2}$")

    @field_validator("p256dh", "auth")
    @classmethod
    def valid_key(cls, value, info):
        raw = base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
        if len(raw) != (65 if info.field_name == "p256dh" else 16):
            raise ValueError("Invalid push key")
        if info.field_name == "p256dh":
            from cryptography.hazmat.primitives.asymmetric import ec
            ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), raw)
        return value


class PushSubscription(BaseModel):
    model_config = ConfigDict(extra="forbid")
    endpoint: str = Field(min_length=20, max_length=2048)
    keys: PushKeys

    _endpoint = field_validator("endpoint")(validate_endpoint)


class SubscriptionChange(BaseModel):
    model_config = ConfigDict(extra="forbid")
    subscription: PushSubscription
    enabled: bool


class PushResult(BaseModel):
    status: Literal["enabled", "disabled", "sent"]


class PushConfig(BaseModel):
    available: bool
    public_key: str | None = None
    reminder_utc_hour: int = 13
    reminder_utc_minute: int = 30


class NoRedirectSession(requests.Session):
    def request(self, *args, **kwargs):
        kwargs["allow_redirects"] = False
        return super().request(*args, **kwargs)


class BrowserPushStore:
    """One bounded private document; shared reviewed CAS/RPC deadlines.

    No client Firestore exception, TTL, paid service or raw scan storage.
    Subscription keys act as a capability for disabling after an auth change.
    """
    def __init__(self, database):
        self.transactions = FirestoreContributionStore(database)

    @property
    def ref(self):
        return self.transactions._ref("unlabel_private_notifications", "browser-v1")

    def mutate(self, callback):
        def operation(transaction):
            raw = self.transactions._batch([self.ref], transaction)[self.ref.path]
            records = (raw or {}).get("records", {})
            if not isinstance(records, dict) or len(records) > MAX_SUBSCRIPTIONS:
                raise StoreUnavailable()
            day = datetime.now(UTC).date().isoformat()
            writes = (raw or {}).get("writes", 0) if (raw or {}).get("day") == day else 0
            if type(writes) is not int or writes >= 1536:
                raise StoreQuotaExceeded()
            result = callback(records)
            transaction.set(self.ref, {"records": records, "writes": writes + 1, "day": day})
            return result
        return self.transactions._run(operation)

    @staticmethod
    def key(subscription):
        return hashlib.sha256(subscription.endpoint.encode()).hexdigest()

    def change(self, actor, body):
        key = self.key(body.subscription)
        now = datetime.now(UTC)
        def operation(records):
            old = records.get(key)
            value = body.subscription.model_dump()
            if old and old["subscription"] != value:
                raise StoreUnavailable()
            if not body.enabled:
                records.pop(key, None)
                return
            if not old:
                if (len(records) >= MAX_SUBSCRIPTIONS
                    or sum(item["actor"] == actor for item in records.values()) >= 3):
                    raise StoreQuotaExceeded()
                records[key] = {"actor": actor, "subscription": value, "created_at": now,
                                "last_test": None, "last_day": None}
        self.mutate(operation)

    def claim(self, subscription, *, test):
        key = self.key(subscription)
        now = datetime.now(UTC)
        day = now.date().isoformat()
        def operation(records):
            record = records.get(key)
            if not record or record["subscription"] != subscription.model_dump():
                return False
            if test:
                if record["last_test"] and now - record["last_test"] < timedelta(minutes=1):
                    raise StoreQuotaExceeded()
                record["last_test"] = now
            else:
                if record["last_day"] == day:
                    return False
                record["last_day"] = day
            return True
        return self.mutate(operation)

    def subscriptions(self):
        raw = self.ref.get(retry=None, timeout=5).to_dict() or {}
        return [PushSubscription.model_validate(v["subscription"])
                for v in raw.get("records", {}).values()][:MAX_SUBSCRIPTIONS]

    def claim_daily(self):
        now = datetime.now(UTC)
        day = now.date().isoformat()
        def operation(records):
            due = []
            for record in records.values():
                if (record["last_day"] == day
                    or (record.get("lease") and record["lease"] > now)):
                    continue
                record["lease"] = now + timedelta(minutes=5)
                due.append(PushSubscription.model_validate(record["subscription"]))
            return due
        return self.mutate(operation)

    def finish_daily(self, results):
        day = datetime.now(UTC).date().isoformat()
        def operation(records):
            for subscription, status in results:
                key = self.key(subscription)
                record = records.get(key)
                if record is None or record["subscription"] != subscription.model_dump():
                    continue
                if status == "expired":
                    records.pop(key)
                else:
                    record["lease"] = None
                    if status == "sent":
                        record["last_day"] = day
        self.mutate(operation)

    def remove(self, subscription):
        self.change("", SubscriptionChange(subscription=subscription, enabled=False))


def deliver(config, subscription, *, test=False):
    # Revalidate at the outbound boundary, including stored records.
    subscription = PushSubscription.model_validate(subscription.model_dump())
    payload = {**REMINDER, "id": "notification-test" if test else REMINDER["id"]}
    if test:
        payload.update(title="Notifications are connected", body="Your browser received this test from Unlabel.")
    with NoRedirectSession() as session:
        session.trust_env = False
        webpush(subscription_info=subscription.model_dump(), data=json.dumps(payload),
                vapid_private_key=config.web_push_private_key.get_secret_value(),
                vapid_claims={"sub": "https://unlabel-india.vercel.app"},
                timeout=4, ttl=3600, requests_session=session)


def build_router(config: Settings) -> APIRouter:
    router = APIRouter(tags=["Notifications"])

    def active(request):
        runtime = request.app.state.community_runtime
        if (not config.web_push_private_key or not config.web_push_public_key
            or runtime is None or not getattr(runtime, "notification_store", None)):
            raise HTTPException(503, "Browser notifications are unavailable. Please try again later.")
        return runtime

    def actor(runtime, authorization):
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(401, "Scanner authentication required")
        try:
            uid = runtime.verify_token(authorization[7:])
            return actor_hash(uid, config.community_actor_secret.get_secret_value())
        except AuthenticationInvalid:
            raise HTTPException(401, "Scanner authentication required") from None
        except AuthenticationUnavailable:
            raise HTTPException(503, "Authentication temporarily unavailable") from None

    @router.get("/v1/notifications", response_model=NotificationFeed)
    def feed(response: Response):
        response.headers["Cache-Control"] = "public, max-age=300"
        return FEED

    @router.get("/v1/notifications/push-config", response_model=PushConfig)
    def push_config(request: Request, response: Response):
        response.headers["Cache-Control"] = "no-store"
        try:
            active(request)
        except HTTPException:
            return PushConfig(available=False)
        return PushConfig(available=True, public_key=config.web_push_public_key)

    @router.post("/v1/notifications/subscription", response_model=PushResult)
    def subscription(request: Request, body: SubscriptionChange,
                     response: Response,
                     authorization: Annotated[str | None, Header(max_length=8199)] = None):
        response.headers["Cache-Control"] = "no-store"
        runtime = active(request)
        owner = actor(runtime, authorization)
        try:
            runtime.notification_store.change(owner, body)
        except StoreQuotaExceeded:
            raise HTTPException(429, "Reminder capacity reached. Please try again later.") from None
        except StoreUnavailable:
            raise HTTPException(503, "Reminder could not be updated. Please retry.") from None
        return PushResult(status="enabled" if body.enabled else "disabled")

    @router.post("/v1/notifications/test", response_model=PushResult)
    def test(request: Request, body: PushSubscription, response: Response,
             authorization: Annotated[str | None, Header(max_length=8199)] = None):
        response.headers["Cache-Control"] = "no-store"
        runtime = active(request)
        actor(runtime, authorization)
        try:
            if not runtime.notification_store.claim(body, test=True):
                raise HTTPException(409, "Enable the daily reminder first.")
            deliver(config, body, test=True)
        except StoreQuotaExceeded:
            raise HTTPException(429, "Wait a minute before sending another test.") from None
        except (StoreUnavailable, WebPushException, requests.RequestException, ValueError):
            raise HTTPException(503, "Test notification could not be delivered. Please retry.") from None
        return PushResult(status="sent")

    @router.get("/v1/notifications/dispatch", include_in_schema=False)
    def dispatch(request: Request,
                 authorization: Annotated[str | None, Header(max_length=8199)] = None):
        secret = config.cron_secret
        if not secret or not hmac.compare_digest(authorization or "", "Bearer " + secret.get_secret_value()):
            raise HTTPException(401, "Unauthorized")
        store = active(request).notification_store
        def send(subscription):
            try:
                deliver(config, subscription)
                return subscription, "sent"
            except WebPushException as error:
                if error.response is not None and error.response.status_code in (404, 410):
                    return subscription, "expired"
                return subscription, "failed"
            except (StoreUnavailable, requests.RequestException, ValueError):
                return subscription, "failed"
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(send, store.claim_daily()))
        store.finish_daily(results)
        statuses = [status for _, status in results]
        return Response(json.dumps({key: statuses.count(key) for key in ("sent", "expired", "failed")}),
                        media_type="application/json", headers={"Cache-Control": "no-store"})
    return router
