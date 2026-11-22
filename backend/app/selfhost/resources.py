"""Bounded service clients. Config values and connection strings stay out of logs."""

import json

import httpx
import redis
from psycopg_pool import ConnectionPool
from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from pymongo import MongoClient

from app.selfhost.catalogue import MongoResearch, PostgresCatalogue


class PlatformSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="UNLABEL_", extra="ignore", hide_input_in_errors=True
    )
    database_url: SecretStr
    mongo_url: SecretStr
    redis_url: SecretStr
    identity_url: str = Field(max_length=2048)
    identity_jwt_secret: SecretStr
    actor_secret: SecretStr
    public_url: str = "https://unlabel.duckdns.org"
    frontend_url: str = "https://unlabel-india.vercel.app"
    web_push_private_key: SecretStr | None = None
    web_push_public_key: str = ""
    community_enabled: bool = False
    worker_kind: str = "worker"
    cutover_ready: bool = False
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: SecretStr | None = None
    smtp_sender: str = ""


class Resources:
    def __init__(self, settings):
        self.settings = settings
        self.pool = ConnectionPool(
            settings.database_url.get_secret_value(),
            min_size=1,
            max_size=6,
            max_waiting=16,
            timeout=3,
            open=False,
            kwargs={
                "connect_timeout": 5,
                "options": "-c statement_timeout=5000 -c lock_timeout=1500",
            },
        )
        self.mongo_client = MongoClient(
            settings.mongo_url.get_secret_value(),
            maxPoolSize=6,
            serverSelectionTimeoutMS=3000,
            connectTimeoutMS=3000,
            socketTimeoutMS=5000,
            retryWrites=False,
            tz_aware=True,
        )
        self.mongo = self.mongo_client.get_database("unlabel_evidence")
        self.cache = redis.Redis.from_url(
            settings.redis_url.get_secret_value(),
            socket_timeout=2,
            socket_connect_timeout=2,
            max_connections=6,
            decode_responses=True,
        )
        self.identity = httpx.Client(
            base_url=settings.identity_url,
            timeout=5,
            follow_redirects=False,
            trust_env=False,
            limits=httpx.Limits(max_connections=6, max_keepalive_connections=3),
        )
        self.catalogue = PostgresCatalogue(self.pool)
        self.research = MongoResearch(self.mongo, self.pool)
        self._closed = False

    def start(self):
        self.pool.open(wait=True, timeout=10)
        self.mongo.command("ping")
        self.cache.ping()

    def health(self):
        with self.pool.connection() as connection:
            connection.execute("SELECT id FROM accounts.users LIMIT 0")
            connection.execute("SELECT avatar_preference FROM accounts.profiles LIMIT 0")
            connection.execute("SELECT id FROM operations.push_subscriptions LIMIT 0")
            connection.execute("SELECT topic,idempotency_key FROM operations.outbox LIMIT 0")
            if self.settings.community_enabled:
                connection.execute("SELECT revision_id FROM community.revisions LIMIT 0")
        if (
            self.catalogue.manifest.indexed_products < 1
            or self.research.status()["observation_count"] < 1
        ):
            raise ValueError("Catalogue imports are incomplete")
        with self.pool.connection() as connection:
            connection.execute("SELECT collection,key FROM ai.documents LIMIT 0")
            connection.execute("SELECT id FROM ai.observations LIMIT 0")
        self.mongo.command("ping")
        self.cache.ping()
        identity = self.identity.get("/health")
        identity.raise_for_status()
        if identity.json().get("version") != "v2.197.0-unlabel.2":
            raise ValueError("Identity account policy is not ready")

    def cached(self, key):
        try:
            raw = self.cache.get("unlabel:cache:" + key)
            return json.loads(raw) if raw and len(raw) <= 131072 else None
        except (redis.RedisError, ValueError):
            return None

    def cache_public(self, key, value):
        raw = json.dumps(value, ensure_ascii=False, allow_nan=False)
        if len(raw.encode()) <= 131072:
            try:
                self.cache.setex("unlabel:cache:" + key, 60, raw)
            except redis.RedisError:
                pass  # Cache availability never substitutes for durable state.

    def close(self):
        if self._closed:
            return
        self._closed = True
        self.identity.close()
        self.cache.close()
        self.mongo_client.close()
        self.pool.close()
