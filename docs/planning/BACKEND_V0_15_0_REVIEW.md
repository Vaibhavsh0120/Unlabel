# Backend 0.15.0 - optional sources and NutriGraph sandbox

Release review, 26-27 October 2026. Source, hosted deployment and vendor connectivity
are separate evidence states.

## Delivered source

All data sources have independent disable controls. Keyed AI/NutriGraph sources
default to credential-based `auto`; explicit false wins, missing keys keep them
off, and OpenAI-only installations choose a valid configured initial slot.
Gemini/OpenAI provider switches also exclude their replacement slots. Community
writes and private sync keep their explicit opt-in and authenticated boundaries.
Missing provider/Firebase configuration leaves affected features unavailable
without preventing backend startup. [Configuration guide](../architecture/OPTIONAL_SOURCES.md).

NutriGraph's supplied key is local server-only configuration, with refreshed
authenticated `.env.age`. No plaintext credential or vendor response is tracked.
The supplied sandbox total is bounded by a non-renewing process cap, with the
existing monthly guard retained. An upstream 429 stops new requests for that
process; HTML 404 endpoint failures report unavailable with a five-minute cooldown.
Process restarts reset local counters; this is not a distributed account quota.
Vendor facts remain exact-identity, provider-unverified, temporary and outside
saved reports, sync and permanent catalogue storage.

## Validation and limits

Final backend verification: 1,493 passed, five emulator-only skips. Full Ruff
checks across backend/scripts passed. Focused source/AI activation checks also
verify that the resolved initial slot, rather than the literal `auto`, reaches
shared selection storage and operator activation. Key setup preserves `auto`.

Two bounded live checks (supplied UPC 811620022118 and documented sample
039978009579) returned HTTP 404 with generic HTML. The local remaining sandbox
cap is 998. The official documented schema informed the parser; no successful
live response, India coverage, or vendor runtime accuracy is claimed.

## Release state

Final local checks passed. Production-only NutriGraph settings were added to the
existing backend Vercel project after verifying it owns `unlabel-api.vercel.app`:
the API key is sensitive/readback-redacted, enable mode is `auto`, and remaining
sandbox process cap is 998. Existing AI settings/keys/selection were preserved.
Those settings are active in the READY backend deployment of pushed implementation
commit `2246edaa32b29fefef640a53081e8d1ecb8ecb3f` on 27 October.
[Repository CI](https://github.com/Vaibhavsh0120/Unlabel/actions/runs/40510533854)
passed, and [backend-v0.15.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.15.0)
was published at that exact source. Authenticated Vercel metadata maps both web/API
production aliases to the same commit. Nineteen
[hosted checks](../research/RELEASE_2026_10_27_PRODUCTION.json) verified API/web
versions, the current OpenAPI export, preserved catalogue/knowledge, private/live
authentication guards and exact decoder assets.

`live_nutrigraph` is configured, and unauthenticated live requests are rejected
before vendor admission. No authenticated vendor lookup, AI extraction or record
write was performed. The prior upstream HTML 404 remains unresolved; configuration
and deployment do not establish successful provider lookup or India coverage.
