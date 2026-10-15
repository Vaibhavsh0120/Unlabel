# Backend 0.14.0 - automatic label observations and live lookup

Working review, 15 October 2026. This additive API update follows published
0.13.0 and preserves historical source bundles, schemas and release receipts.

## Delivered source

AI extraction accepts optional `catalogue_contribution: machine-unverified-v1`.
After normal authenticated extraction, compatible back-label facts can enter a
separate immutable machine-observation stream. Evidence remains
`machine_extracted_unverified`; no human-confirmation flag is fabricated.
Name, brand, size, variant and barcode compatibility are checked against known
source identities. Unknown/conflicting identities cannot attach facts to a SKU.
Original catalogue/community observations are never overwritten. Semantic
deduplication, per-product/global bounds and read-time disagreements remain.

`GET /v1/ai/observations/{barcode}` exposes qualified machine readings separately
from human-confirmed reports. Photos, raw OCR, regions, credentials, personal
profiles and account identities are absent from public observations.

`GET /v1/live-products/nutrigraph/{barcode}` is an optional authenticated scanner
lookup. The server owns the key and fixed HTTPS endpoint. Only documented,
checksum-valid UPC-12 codes are sent. Stated fields retain source information;
computed dietary/allergen labels and qualified backfills are not safety proof.
Responses are no-store; memory cache retention never exceeds 24 hours. Coalescing,
body/time/concurrency/actor bounds and a process-local monthly budget limit load.
The vendor must enforce the account-wide free quota across serverless workers.
No vendor facts enter permanent catalogue, AI-admission or private-library data.

NutriGraph remains disabled without explicit settings and a server-side trial key.
The user sent the trial email on 15 October and will supply a reply later. No key,
payment, subscription or provider data submission was performed by this update.
India/EAN-13 coverage remains unverified; product names use the local catalogue
first, with a selected supported barcode used for live lookup.

`POST /v1/claims/catalogue-check` compares bounded front claim strings against
known exact product-source tables and reviewed numeric criteria. It accepts no
client nutrition or confirmation flag. Unknown product form/category, source
conflicts and current-package uncertainty stay explicit; numeric pass/fail rows
are not an overall claim/compliance verdict.

## Validation and limits

Local release checks on 15 October: 1,481 backend tests passed, five credential/
provider-dependent tests skipped. The focused backend suite also passed after the
research nutrient-dimension guard: energy units cannot become grams or vice versa.
Ruff, locked Python dependency consistency and current contract exports passed.
The API has 30 paths / 32 operations; the production-preview allowlist includes
all app operations while machine activation remains excluded. The sole test
warning comes from the pinned FastAPI/Starlette TestClient dependency.

Tests cover immutable admission, deduplication/conflicts, identity/body bounds,
authentication, provider isolation, cache expiry/no persistence and source-only
claim arithmetic. Live NutriGraph calls are untested pending the key. No camera
or AI accuracy guarantee follows from adapter tests.

## Release state

Local validation is complete. Source publication and hosted deployment are
recorded separately after publication. Frontend 0.10.0+14 has its own native release evidence.
