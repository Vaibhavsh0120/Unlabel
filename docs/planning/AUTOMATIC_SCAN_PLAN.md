# Automatic scan and product results

Accepted direction, 8 October 2026: a shopper opens Scan, photographs a barcode or
package and gets readable product facts without mandatory transcription. The
four supplied references establish mobile/desktop results composition and real
photo highlights. This replaces the normal Enter package label route.

## User flow

1. Start the existing camera without waiting for gallery recovery or model loads.
2. Decode a captured barcode locally before OCR. Exact database hits open sourced
   nutrient results; missing facts offer a back-label photo, never a required form.
3. Front photos supply identity/claims; back photos supply ingredients, declared
   allergens and explicitly based nutrient rows. Reading starts automatically.
4. Paint normalized, actually detected text regions over the captured photo.
   Use neutral labels for detected ingredients/nutrients; color never establishes
   a health/allergy conclusion. The action becomes View results when useful facts
   are ready. Unreadable/ambiguous content requests a specific clearer photo.
5. Match name/brand/variant/quantity, barcode, ingredient and claim evidence in a
   linked product index. Ambiguous products require a visual selection, not typing.
6. Unknown products still produce an extraction-qualified result. One optional
   tap verifies extracted fields for public catalogue admission; raw AI/OCR never
   claims user confirmation or silently changes canonical product facts.

## Architecture and privacy

- Preserve acquired OFF and researched sources, immutable receipts and exact-SKU
  conflicts. Shared product links need compatible identities; barcode leads and
  family pages cannot silently merge variants.
- Local-first barcode and OCR are free/offline. Preserve model/worker reuse and
  bounded pixels/bytes/cancellation. Extend OCR results with line/word geometry,
  keeping text-only compatibility for existing tests/callers.
- Optional backend Gemini or OpenAI vision improves difficult extraction. Use a server-only
  secret, bounded image requests, structured JSON and deterministic validation.
  A missing key, quota, timeout or malformed response returns a useful local path.
  No billing activation or unconfigured paid fallback. User authorized this
  hybrid choice and offered a key; configuration/live provider proof are separate.
- Exactly one globally active credential serves every AI task and user. A shared
  Firestore pointer survives server restarts. Manual selection uses an expected
  revision; failures may atomically select one configured replacement. Selection
  stays there until another manual change or failure; there is no task-specific
  routing or rotation on success. In-flight requests admitted before a switch may
  finish. A failed current request gets at most one replacement attempt. Respect
  quota cooldowns and shared request limits; replacements are supplied by the
  operator, never created automatically. OpenAI remains optional and user-funded.
- Our backend does not retain photos or raw OCR. Google free-tier data-use terms
  are shown before optional image transfer; do not promise provider zero retention.
  Photos remain outside account sync and public product records.
- Public accepted facts retain capture method, extraction qualification and
  provenance. New unverified extraction goes to staging, not confirmed facts.
- Product images are validated sourced URLs or a session-only captured front
  photo. Missing real images show an honest fallback; fabricated package imagery
  cannot satisfy image coverage. Acquire verified descriptors where possible.

## Results contract and reference adaptation

Product identity/image card, mint botanical summary, factual reasons, front-claim
cards, nutrition snapshot, ingredient insights, allergen declaration and sources.
Mobile stacks these; PC uses a main column and ingredient/source side column.
Existing Save/history/Compare workflows stay functional. An illustrative 85/100,
Good Choice, low/high labels and invented health explanations are never copied as
facts. If a score is added later it requires a documented, evaluated rubric.

## Delivery and acceptance

Backend 0.10/frontend 0.5 research sources and backend 0.11 extraction are already
pushed with READY deployments and read-only hosted receipts; authenticated AI
generation, local next versions and physical-device proof remain separate.
Frontend 0.6 replaces the manual route and result composition. Backend 0.12 adds
bounded private machine proposals, search v3 and separate image descriptors.
These next changes were reviewed locally on `main`. The user's latest instruction
authorizes independent pushes after completing review and documentation.
No worktrees, mobile builds for backend-only work or paid Firebase services.

Tests cover barcode image decoding/checksum, malformed/oversized/cancelled images,
OCR geometry mapping with contain-fit/rotation, uncertain/duplicate table cells,
identity ambiguity, provider errors/privacy, staging admission and fast exact hits.
Render matching 390/1440/1728 widths with real states, measure spacing, validate
known barcode-only and unknown front/back workflows, and verify exact deployment
SHAs/versions. 3–5 seconds is a measurement target for warm known products, not a promise
for every cold camera/model/download/network/unknown package. Physical Android/iOS
camera/accuracy and provider quota remain explicit until actually observed.

## Database choice, 8 October 2026

The user requested the best storage choice rather than mandating Firebase. Keep
SQLite as the read-only deployed public catalogue; add new sourced facts through
validated source bundles and rebuild it. Firestore stores mutable community facts,
private accounts, global AI selection and bounded private machine proposals.
Vercel runtime writes cannot serve as
persistent SQLite catalogue updates. Preserve all existing data and export a
verified local backup before maintenance; do not delete or overwrite new records.

The local research search v3 rebuild preserves all 243 original rows/source
observations and adds ingredient/declaration/recorded claim terms. Separate
sourced-image descriptors currently cover 120/243 observations; the remaining
123 keep a missing-image state. See the
[preservation receipt](../research/RESEARCH_SEARCH_V3_PRESERVATION.json) and
[image receipt](../research/RESEARCH_PRODUCT_IMAGES_2026_10_08.json).
