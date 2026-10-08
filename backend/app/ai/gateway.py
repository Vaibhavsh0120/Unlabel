"""Every AI operation obtains the same shared active credential at admission."""

from datetime import UTC, datetime

import httpx
from starlette.concurrency import run_in_threadpool

from app.ai.configuration import configuration_digest, credentials
from app.ai.models import ExtractedLabel, ExtractionRequest
from app.ai.providers import Credential, ProviderFailure, extract
from app.ai.store import ActiveSelection, AiSelectionStore
from app.community.store import StoreUnavailable
from app.core.config import Settings


class AiGateway:
    def __init__(self, config: Settings, store: AiSelectionStore, client: httpx.AsyncClient) -> None:
        self.config = config
        self.store = store
        self.client = client
        self.credentials = credentials(config)
        self.by_id = {value.id: value for value in self.credentials}
        self.configuration = configuration_digest(self.credentials)
        if config.ai_initial_credential_id not in self.by_id:
            raise ValueError("Initial AI credential is not configured")

    async def selection(self) -> ActiveSelection:
        return await run_in_threadpool(
            self.store.read, self.config.ai_initial_credential_id, self.configuration,
        )

    async def runnable_selection(self) -> ActiveSelection:
        current = await self.selection()
        if current.configuration != self.configuration:
            raise StoreUnavailable()
        now = datetime.now(UTC)
        until = current.blocked_until.get(current.credential_id)
        if until is not None and until > now and self.config.ai_failover_enabled:
            eligible = [
                key for key in self.by_id if key != current.credential_id
                and (key not in current.blocked_until or current.blocked_until[key] <= now)
            ]
            if eligible:
                # An earlier failed slot may have recovered while the active slot
                # is still blocked. Change the shared pointer, never a local pick.
                current = await run_in_threadpool(
                    self.store.failed, current, tuple(self.by_id),
                    min(86400, max(1, int((until - now).total_seconds()))),
                )
        self.credential(current)
        return current

    def credential(self, selection: ActiveSelection) -> Credential:
        if selection.configuration != self.configuration:
            raise StoreUnavailable()
        value = self.by_id.get(selection.credential_id)
        if value is None:
            raise StoreUnavailable()
        until = selection.blocked_until.get(value.id)
        if until is not None and until > datetime.now(UTC):
            raise ProviderFailure(kind="quota", cooldown_seconds=min(
                86400, max(1, int((until - datetime.now(UTC)).total_seconds())),
            ))
        return value

    async def extract(self, actor: str, request: ExtractionRequest) -> tuple[ExtractedLabel, ActiveSelection]:
        selection = await self.runnable_selection()
        # Do not consume admission quota when selection cannot run.
        self.credential(selection)
        await run_in_threadpool(
            self.store.admit, actor,
            daily_limit=self.config.ai_daily_request_limit,
            actor_limit=self.config.ai_actor_daily_limit,
        )
        attempted: set[str] = set()
        for attempt in range(2):
            # A manual switch during admission applies before the outbound call.
            selection = await self.runnable_selection()
            selected = self.credential(selection)
            if selected.id in attempted:
                raise ProviderFailure(kind="transient", cooldown_seconds=60)
            attempted.add(selected.id)
            try:
                result = await extract(self.client, selected, request)
                return result, selection
            except ProviderFailure as error:
                # Malformed individual output is not evidence of a failed key.
                if error.kind in {"invalid_response", "busy"}:
                    raise
                candidates = tuple(self.by_id) if self.config.ai_failover_enabled else ()
                replacement = await run_in_threadpool(
                    self.store.failed, selection, candidates, error.cooldown_seconds,
                )
                if attempt == 1 or replacement.credential_id in attempted:
                    raise
                # The next iteration reads global state again; no private override.
        raise StoreUnavailable()
