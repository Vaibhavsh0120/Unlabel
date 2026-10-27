# Backend 0.15.0 - optional sources and NutriGraph sandbox

Working review, 26-27 October 2026. Source, hosted deployment and vendor connectivity
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
This changes configuration for the next deployment; it does not prove provider
success. Source commit/push and hosted verification are recorded after publication.
