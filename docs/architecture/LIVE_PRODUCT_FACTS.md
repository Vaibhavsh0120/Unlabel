# Live external product facts

NutriGraph is an optional live display source, separate from Unlabel's catalogue,
report history, synced libraries, comparison facts and AI observations. The
integration is disabled until a backend-only trial key is configured. Mock tests
do not establish provider coverage or live response compatibility.

## Request and evidence boundaries

`GET /v1/live-products/nutrigraph/{barcode}` requires the existing Firebase
scanner identity when enabled; anonymous scanner tokens are accepted. The
backend sends only the barcode and its vendor credential to the fixed HTTPS
lookup endpoint. It never sends user IDs, names, dietary settings or photographs.
Redirects and environment proxies are disabled. A request has a ten-second
overall deadline, a 512 KiB upstream body limit, and a 128 KiB normalized display
limit. Failures return sanitized status without upstream error bodies or secrets.

The published lookup contract documents UPC-12. Only a checksum-valid 12-digit
barcode is sent, preserving leading zeros and requiring an exact response barcode.
Other GTIN formats remain unsupported by this adapter until vendor lookup support
is verified. A name search must first select a catalogue product and package size;
that product's barcode can then be looked up. There is no vendor name-search call.

The display DTO is explicitly `external_provider_unverified`. It retains source
references alongside selected ingredient names, stated allergen declarations and
stated nutrition. AI-qualified safety flags, scores and backfilled nutrient values
do not replace package declarations or generate an allergy-safe verdict. Missing
or incompatible fields remain absent. Original catalogue/report facts remain
unchanged. Every visible vendor section must show the linked credit
`Data by NutriGraphAPI` and expire at the response's `expires_at` timestamp.

## Retention and quota

The server has a memory-only LRU cache of at most 64 normalized responses.
Successful responses expire no later than 24 hours after retrieval, with scheduled
removal and an additional expiry check on lookup. Failed responses are briefly
coalesced; no disk, Firestore, SQLite, export or library write is performed. Shutdown
clears the cache and cancels pending requests. The client must keep this DTO only
in the open page and clear it on expiry/disposal; it is not part of `ProductReport`.

Concurrent requests for one barcode share one operation. The process permits two
concurrent upstream calls and 30 uncached calls per actor per UTC day. Its monthly
counter is an additional per-process guard capped at 1,000; it resets on a cold
start and is **not** an account-wide quota ledger. The vendor's free plan enforces
the account-wide 1,000-call calendar-month hard limit. A vendor 429 blocks further
uncached requests until the next UTC month. There is no paid-plan activation,
overage purchasing, automatic product submission or bulk enumeration.

## Configuration and verification

`backend/.env.example` documents `NUTRIGRAPH_ENABLED`, `NUTRIGRAPH_API_KEY` and
`NUTRIGRAPH_MONTHLY_REQUEST_LIMIT`. Use the existing backend environment/encryption
workflow for a supplied key; never put it in Flutter or a public runtime manifest.
The configured Firebase community runtime is required. `live_nutrigraph` metadata
stays false if either the key or runtime is missing.

After receiving a key, verify a bounded representative UPC sample and obtain
explicit EAN-13/India coverage guidance before changing supported formats. No key
has been used for the current implementation's tests. Existing Unlabel product
information remains available when the vendor is disabled, misses, times out or
exhausts its free quota.

The [official API documentation](https://www.nutrigraphapi.com/docs.html) and
[terms](https://www.nutrigraphapi.com/legal.html), checked on 15 October 2026,
require attribution and limit performance caching to 24 hours. Their terms prohibit
using responses to populate a retained catalogue. Retention cannot be expanded by
Unlabel's own terms. Test fixtures are synthetic and contain no provider records.
