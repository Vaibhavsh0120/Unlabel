"""Bounded live-only adapter. No vendor response is written to persistent storage."""

import asyncio
import json
import math
import re
from collections import OrderedDict
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

import httpx

from app.core.json_numbers import checked_float, reject_constant
from app.live_products.models import LiveField, LiveLookup, LiveProduct

LOOKUP_URL = "https://barcode-api-140543331861.asia-south1.run.app/api/lookup"
MAX_RESPONSE_BYTES = 512 * 1024
MAX_DISPLAY_BYTES = 128 * 1024
CACHE_SECONDS = 24 * 60 * 60
MAX_CACHE_ENTRIES = 64
MAX_PENDING = 2


def _text(value: object, maximum: int = 1000) -> str | None:
    if not isinstance(value, str) or len(value) > maximum:
        return None
    if any(ord(c) < 32 and c not in "\n\t" or "\ud800" <= c <= "\udfff" for c in value):
        return None
    return value.strip() or None


def _sources(value: object) -> tuple[str, ...]:
    """Retain provenance attached to the selected data, including nested source fields."""
    found: list[str] = []

    def visit(node: object, path: str, depth: int) -> None:
        if depth > 12:
            raise ValueError("Vendor provenance nesting exceeds bound")
        if isinstance(node, dict):
            for key, item in node.items():
                if key in {"source", "data_source", "data_last_updated"}:
                    raw = item if isinstance(item, str) else json.dumps(item, ensure_ascii=True)
                    note = _text(raw, 2000)
                    if note is None and item is not None:
                        raise ValueError("Vendor provenance exceeds bound")
                    if note is not None:
                        found.append(f"{path}{key}: {note}")
                elif isinstance(item, (dict, list)):
                    visit(item, f"{path}{key}.", depth + 1)
        elif isinstance(node, list):
            for index, item in enumerate(node):
                visit(item, f"{path}{index}.", depth + 1)

    visit(value, "", 0)
    if len(found) > 128 or sum(map(len, found)) > 16000:
        raise ValueError("Vendor provenance exceeds bound")
    return tuple(dict.fromkeys(found))


def normalize(data: object, barcode: str, now: datetime) -> LiveProduct:
    """Select labelled facts; never interpret AI dietary/allergen flags as safety verdicts."""
    if (not supported_upc(barcode) or not isinstance(data, dict)
        or not isinstance(data.get("analysed_data"), dict)):
        raise ValueError("Missing vendor object")
    analysed = data["analysed_data"]
    general = analysed.get("generalData")
    if not isinstance(general, dict) or general.get("upc12") != barcode:
        raise ValueError("Vendor identity does not match")
    fields: list[LiveField] = []
    ingredients = analysed.get("ingredients")
    if isinstance(ingredients, list) and 0 < len(ingredients) <= 200:
        names = [_text(item.get("name"), 300) if isinstance(item, dict) else None
                 for item in ingredients]
        complete_names = [name for name in names if name is not None]
        if len(complete_names) == len(names) and len("; ".join(complete_names)) <= 6000:
            fields.append(LiveField(
                section="ingredients", label="Provider ingredient list",
                value="; ".join(complete_names), sources=_sources(ingredients),
            ))
    allergens = analysed.get("npiFoodPackagesAllergensIntolerances")
    if isinstance(allergens, dict):
        labels = {
            "eggStated": "Egg declaration", "dairyStated": "Dairy declaration",
            "glutenLevelStated": "Gluten declaration", "fishStated": "Fish declaration",
            "caseinStated": "Casein declaration",
            "falcpaCommonAllergensStated": "Provider allergen declaration",
        }
        provenance = _sources(allergens)
        for key, label in labels.items():
            if value := _text(allergens.get(key)):
                fields.append(LiveField(
                    section="allergens", label=label, value=value, sources=provenance,
                ))
        additional = allergens.get("additionalInfo")
        if isinstance(additional, dict) and (value := _text(additional.get("traces"))):
            fields.append(LiveField(
                section="allergens", label="Provider trace statement", value=value,
                sources=provenance,
            ))
    nutrition = analysed.get("nutritionalInformation")
    stated = nutrition.get("stated") if isinstance(nutrition, dict) else None
    if isinstance(stated, dict):
        # Qualified/backfilled nutrition is deliberately not substituted for stated values.
        for group in ("macronutrients", "micronutrients"):
            entries = stated.get(group)
            if not isinstance(entries, list) or len(entries) > 40:
                continue
            for item in entries:
                if not isinstance(item, dict):
                    continue
                name, unit, value = _text(item.get("name"), 120), _text(item.get("unit"), 12), item.get("value")
                if (name and unit in {"g", "mg", "mcg", "µg", "kcal", "kJ"}
                    and type(value) in {int, float} and 0 <= value <= 100000 and math.isfinite(value)):
                    fields.append(LiveField(
                        section="nutrition", label=f"{name} (per 100 g, provider stated)",
                        value=f"{value:g} {unit}", sources=_sources(item),
                    ))
    root_sources = {key: value for key, value in data.items()
                    if key in {"source", "data_source", "data_last_updated"}}
    for key in ("source", "data_source", "data_last_updated"):
        if key in analysed:
            root_sources[f"analysed_{key}"] = {key: analysed[key]}
    if stated is not None:
        root_sources["stated_nutrition"] = stated
    if isinstance(nutrition, dict):
        root_sources["nutrition"] = {key: value for key, value in nutrition.items()
                                     if key in {"source", "data_source", "data_last_updated"}}
    root_sources["general"] = general
    result = LiveProduct(
        barcode=barcode, name=_text(general.get("productName"), 240),
        brand=_text(general.get("brandName"), 200), fields=tuple(fields),
        sources=_sources(root_sources), retrieved_at=now,
        expires_at=now + timedelta(seconds=CACHE_SECONDS),
    )
    if len(result.model_dump_json().encode()) > MAX_DISPLAY_BYTES:
        raise ValueError("Vendor display exceeds bound")
    return result


def supported_upc(barcode: str) -> bool:
    if not re.fullmatch(r"[0-9]{12}", barcode):
        return False
    return sum(int(c) * (3 if i % 2 == 0 else 1) for i, c in enumerate(barcode)) % 10 == 0


class NutriGraphLookup:
    """One-process cache/budget; the free vendor plan enforces the account-wide hard quota."""

    def __init__(self, client: httpx.AsyncClient, api_key: str, *,
                 monthly_limit: int = 1000, clock: Callable[[], datetime] | None = None):
        self.client, self._key = client, api_key
        self._clock = clock or (lambda: datetime.now(UTC))
        self._monthly_limit = monthly_limit
        self._month = ""
        self._requests = 0
        self._blocked_until: datetime | None = None
        self._blocked_status = "rate_limited"
        self._cache: OrderedDict[str, tuple[datetime, LiveLookup, asyncio.TimerHandle]] = OrderedDict()
        self._pending: dict[str, asyncio.Task[LiveLookup]] = {}
        self._actors: dict[str, int] = {}
        self._day = ""
        self._lock = asyncio.Lock()
        self._closed = False

    def _expire(self, barcode: str) -> None:
        if value := self._cache.pop(barcode, None):
            value[2].cancel()

    def _put(self, barcode: str, result: LiveLookup, now: datetime, seconds: int) -> None:
        if self._closed:
            return
        self._expire(barcode)
        while len(self._cache) >= MAX_CACHE_ENTRIES:
            self._expire(next(iter(self._cache)))
        seconds = min(seconds, CACHE_SECONDS)
        expires = now + timedelta(seconds=seconds)
        if result.product is not None:
            # Cache insertion must not extend the original response's retention window.
            expires = min(expires, result.product.expires_at)
            seconds = max(0, (expires - now).total_seconds())
        if seconds <= 0:
            return
        timer = asyncio.get_running_loop().call_later(seconds, self._expire, barcode)
        self._cache[barcode] = (expires, result, timer)

    async def lookup(self, barcode: str, actor: str) -> LiveLookup:
        if not supported_upc(barcode):
            return LiveLookup(status="unsupported_barcode", requested_barcode=barcode)
        async with self._lock:
            now = self._clock()
            for key, (expires, _, _) in list(self._cache.items()):
                if expires <= now:
                    self._expire(key)
            if self._closed:
                return LiveLookup(status="unavailable", requested_barcode=barcode)
            if cached := self._cache.get(barcode):
                self._cache.move_to_end(barcode)
                return cached[1]
            operation = self._pending.get(barcode)
            if operation is None:
                month, day = now.strftime("%Y-%m"), now.strftime("%Y-%m-%d")
                if month != self._month:
                    self._month, self._requests = month, 0
                if day != self._day:
                    self._day, self._actors = day, {}
                if self._requests >= self._monthly_limit:
                    return LiveLookup(status="rate_limited", requested_barcode=barcode,
                                      retry_after=self._month_wait(now))
                if self._blocked_until is not None and now < self._blocked_until:
                    return LiveLookup(status=self._blocked_status, requested_barcode=barcode,
                                      retry_after=math.ceil((self._blocked_until - now).total_seconds()))
                if self._actors.get(actor, 0) >= 30:
                    midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
                    return LiveLookup(status="rate_limited", requested_barcode=barcode,
                                      retry_after=math.ceil((midnight - now).total_seconds()))
                if (len(self._pending) >= MAX_PENDING
                    or (actor not in self._actors and len(self._actors) >= 256)):
                    return LiveLookup(status="rate_limited", requested_barcode=barcode, retry_after=60)
                self._requests += 1
                self._actors[actor] = self._actors.get(actor, 0) + 1
                operation = asyncio.create_task(self._fetch(barcode))
                self._pending[barcode] = operation
        # One disconnected caller must not cancel an already-counted shared upstream request.
        return await asyncio.shield(operation)

    @staticmethod
    def _month_wait(now: datetime) -> int:
        next_month = (now.replace(day=1) + timedelta(days=32)).replace(day=1, hour=0, minute=0,
                                                                     second=0, microsecond=0)
        return max(1, math.ceil((next_month - now).total_seconds()))

    async def _fetch(self, barcode: str) -> LiveLookup:
        result = LiveLookup(status="unavailable", requested_barcode=barcode, retry_after=30)
        seconds = 30
        try:
            async with asyncio.timeout(10):
                async with self.client.stream(
                    "GET", LOOKUP_URL, params={"barcode": barcode},
                    headers={"X-API-Key": self._key, "Accept": "application/json",
                             "Accept-Encoding": "identity"}, follow_redirects=False,
                    timeout=httpx.Timeout(8, connect=3, pool=2),
                ) as response:
                    if response.status_code == 404:
                        result = LiveLookup(status="not_found", requested_barcode=barcode)
                        seconds = 300
                    elif response.status_code == 429:
                        now = self._clock()
                        wait = self._month_wait(now)
                        self._blocked_until = now + timedelta(seconds=wait)
                        self._blocked_status = "rate_limited"
                        result = LiveLookup(status="rate_limited", requested_barcode=barcode,
                                            retry_after=wait)
                    elif response.status_code in {401, 403}:
                        self._blocked_until = self._clock() + timedelta(minutes=5)
                        self._blocked_status = "unavailable"
                    elif response.status_code == 200:
                        if response.headers.get("content-encoding", "identity") not in {"", "identity"}:
                            raise ValueError("Unexpected compressed vendor response")
                        if "application/json" not in response.headers.get("content-type", "").lower():
                            raise ValueError("Invalid vendor content type")
                        body = bytearray()
                        async for chunk in response.aiter_bytes(chunk_size=16384):
                            if len(body) + len(chunk) > MAX_RESPONSE_BYTES:
                                raise ValueError("Vendor response too large")
                            body.extend(chunk)
                        value = json.loads(body, parse_float=checked_float, parse_constant=reject_constant)
                        product = normalize(value, barcode, self._clock())
                        result = LiveLookup(status="found", requested_barcode=barcode, product=product)
                        seconds = CACHE_SECONDS
        except (httpx.HTTPError, TimeoutError, ValueError, UnicodeDecodeError, RecursionError):
            pass  # Never echo upstream bodies, credentials or arbitrary exception strings.
        finally:
            self._pending.pop(barcode, None)
        self._put(barcode, result, self._clock(), seconds)
        return result

    async def close(self) -> None:
        self._closed = True
        tasks = list(self._pending.values())
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self._pending.clear()
        for key in list(self._cache):
            self._expire(key)
        self._actors.clear()
        self._key = ""
        await self.client.aclose()
