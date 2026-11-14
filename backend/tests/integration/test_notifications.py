import base64
from typing import cast

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient
from pydantic import SecretStr, ValidationError

from app.api.v1.community import CommunityRuntimeProtocol
from app.core.config import Settings
from app.main import create_app
from app.notifications import BrowserPushStore, PushSubscription, SubscriptionChange
from tests.integration.test_personal_sync_api import Runtime


def subscription(index=0, host="fcm.googleapis.com"):
    public = ec.generate_private_key(ec.SECP256R1()).public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    def encode(raw):
        return base64.urlsafe_b64encode(raw).decode().rstrip("=")
    return {"endpoint": f"https://{host}/fcm/send/synthetic-{index}",
            "keys": {"p256dh": encode(public), "auth": encode(b"x" * 16)}}


def client(runtime=None):
    config = Settings(_env_file=None, community_enabled=runtime is not None,
                      community_actor_secret=SecretStr("x" * 32),
                      web_push_private_key=SecretStr("synthetic-not-a-key"),
                      web_push_public_key="synthetic-public", cron_secret=SecretStr("cron-test"))
    return TestClient(create_app(config, httpx.MockTransport(lambda _: pytest.fail("No products")),
                                 cast(CommunityRuntimeProtocol, runtime)))


def test_public_feed_is_bounded_cacheable_and_contains_no_private_activity():
    with client() as api:
        response = api.get("/v1/notifications")
        assert response.status_code == 200
        assert response.headers["cache-control"] == "public, max-age=300"
        assert 0 < len(response.json()["items"]) <= 20
        assert api.get("/v1/notifications/push-config").json()["available"] is False
        assert api.get("/v1/notifications/dispatch").status_code == 401


@pytest.mark.parametrize("host", ["127.0.0.1", "localhost", "169.254.169.254",
                                 "fcm.googleapis.com.evil.test", "evil.test"])
def test_subscription_rejects_private_and_arbitrary_destinations(host):
    with pytest.raises(ValidationError):
        PushSubscription.model_validate(subscription(host=host))


def test_authenticated_subscribe_test_rate_limit_and_unsubscribe(monkeypatch):
    runtime = Runtime()
    runtime.notification_store = BrowserPushStore(runtime.database)
    body = subscription()
    headers = {"Authorization": "Bearer anonymous"}
    deliveries = []
    monkeypatch.setattr("app.notifications.deliver", lambda *args, **kwargs: deliveries.append(kwargs))
    with client(runtime) as api:
        assert api.get("/v1/notifications/push-config").json()["available"] is True
        assert api.post("/v1/notifications/subscription", json={"subscription": body, "enabled": True}).status_code == 401
        for _ in range(2):
            assert api.post("/v1/notifications/subscription", json={"subscription": body, "enabled": True}, headers=headers).json() == {"status": "enabled"}
        assert api.post("/v1/notifications/test", json=body, headers=headers).json() == {"status": "sent"}
        assert api.post("/v1/notifications/test", json=body, headers=headers).status_code == 429
        assert len(deliveries) == 1
        assert api.post("/v1/notifications/subscription", json={"subscription": body, "enabled": False}, headers=headers).json() == {"status": "disabled"}
        assert api.post("/v1/notifications/test", json=body, headers=headers).status_code == 409
    assert runtime.notification_store.subscriptions() == []


def test_daily_dispatch_lease_deduplication_and_failure_retry(monkeypatch):
    runtime = Runtime()
    store = runtime.notification_store = BrowserPushStore(runtime.database)
    item = PushSubscription.model_validate(subscription())
    store.change("actor", SubscriptionChange(subscription=item, enabled=True))
    first = store.claim_daily()
    assert first == [item]
    assert store.claim_daily() == []
    store.finish_daily([(item, "failed")])
    calls = []
    monkeypatch.setattr("app.notifications.deliver", lambda *args, **kwargs: calls.append(True))
    with client(runtime) as api:
        assert api.get("/v1/notifications/dispatch", headers={"Authorization": "Bearer wrong"}).status_code == 401
        headers = {"Authorization": "Bearer cron-test"}
        assert api.get("/v1/notifications/dispatch", headers=headers).json()["sent"] == 1
        assert api.get("/v1/notifications/dispatch", headers=headers).json()["sent"] == 0
    assert calls == [True]


def test_owner_capacity_and_unsubscribe_after_identity_change():
    runtime = Runtime()
    store = BrowserPushStore(runtime.database)
    items = [PushSubscription.model_validate(subscription(i)) for i in range(4)]
    from app.community.store import StoreQuotaExceeded
    for item in items[:3]:
        store.change("actor", SubscriptionChange(subscription=item, enabled=True))
    with pytest.raises(StoreQuotaExceeded):
        store.change("actor", SubscriptionChange(subscription=items[3], enabled=True))
    store.change("new-identity", SubscriptionChange(subscription=items[0], enabled=False))
    assert len(store.subscriptions()) == 2
