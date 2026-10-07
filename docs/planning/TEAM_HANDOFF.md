# Teammate handoff

Restore from root with python scripts/setup.py and run with
python scripts/run_local.py; PowerShell wrappers remain available.
Setup preserves local settings, can restore encrypted backend/.env.age, verifies
the tracked India source and builds the current discovery index with progress.
[Recovery guide](LOCAL_DEVELOPMENT.md).

## Current checkpoint

Backend **0.6.0 Product Discovery** and frontend **0.1.0+2 Connected Label Reader**
have separate release gates: backend v0.6.0 is already published; frontend v0.1.0+2 is implemented with final rendered/release checks pending. Backend local verification:
**863 passed, 5 emulator-only skipped**, Ruff/Pyright clean, nineteen exported
routes and old eighteen-route compatibility preserved. Frontend analysis and
interaction/data tests passed before final layout adjustments; the 42-test suite must pass again with those changes. Backend exact deployment and 23 hosted checks passed. Frontend browser/push/publication are separate gates, tracked in the [connected release plan](CONNECTED_RELEASE_PLAN.md)
and [backend review](BACKEND_V0_6_0_REVIEW.md).

Historical production **v0.5.0 Useful Label Report** and **v0.4.0 Community Product Catalogue**
were independently pushed, hosted-verified and published. Preserve their source
tags and evidence: [v0.5.0 proof](../research/BACKEND_V0_5_0_PRODUCTION.json),
[v0.4.0 proof](../research/BACKEND_V0_4_0_PRODUCTION.json).
Earlier review/test counts are historical, not the next release's hosted proof.

Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app).
API: [unlabel-api.vercel.app](https://unlabel-api.vercel.app).
[Deployment configuration](VERCEL_SETUP.md).

Next accepted backend v0.7.0/frontend v0.2.0 adds optional scanner login/private
sync and completes all visible reference-style destinations one screen at a time,
beginning with Home. Guests retain local features; public package facts remain
separate. [Accepted next scope](ACCOUNT_SYNC_SCREEN_PLAN.md).

## What the person can do

The Flutter home opens manual barcode lookup or bounded name/brand search.
Candidates show identifying fields and require explicit selection. The historical
report preserves source dates, unavailable facts and conflicts.

The dedicated label form accepts the current package's identity, claims,
ingredient/allergen declarations and nutrient rows with printed basis/unit/
preparation. Independent confirmation/pairing precedes analysis. An unchanged
retry keeps its submission ID; changing facts creates a fresh submission.
Structured public facts save automatically through anonymous scanner Auth.
Storage/auth failures are distinct from the useful report outcome.

Reports show sourced current/historical facts, approximate original-basis sugar
cubes, the reviewed numerical claim subset and only three English/Hindi ingredient
functions. The person can explicitly bookmark a report and reopen bounded private
device-local saved/history lists. Appearance uses the owner's white/forest/mint
direction, real Material 3 controls and locally licensed Solar icons.

No camera/gallery/OCR, comparison, suitability profile, AI calls, training or fake
85/100 score is part of this frontend release. Native device validation remains
separate from the web/widget checks.

## Integration and ownership

| Area | Current implementation |
| --- | --- |
| Client composition | frontend/lib/app, one Flutter app for Android/iOS/web |
| Client data | core/models, network and storage: bounded validation/HTTP, cached metadata handshake, lazy anonymous Auth and local persistence |
| Client pages | features/scanner/presentation: home, lookup, form, report, ingredient detail, saved/history |
| Backend discovery | app/catalogue/search.py and optional indexed SQLite tables; no upstream search call |
| Report | app/reports and existing report routes; sources/dates/unknowns retained |
| Community facts | app/community: deduplication, private staging, qualified compatible observations and unresolved conflicts |
| Source/recovery | data/catalogue, scripts/setup.py and tracked encrypted environment; generated SQLite/SDKs remain ignored |

Name search covers the measured OFF snapshot, not community-only products.
Barcode reports can use exact source resolution; this does not confirm a current
packet. New source catalogs must preserve licensing, identity and per-field
provenance. Generic raw-food composition must not fill branded packet gaps.

The source contains **24,641** supported India-tagged OFF identities; **4,519**
have reported direct nutrient values. This is source content, not measured Indian
retail coverage. The acquisition source date is **2026-10-06T06:53:46Z**, with manual
nine-calendar-month replacement due **2027-07-06T06:53:46Z**.
[Measured source](../research/CATALOGUE_V0_2_3_COVERAGE.json).

## Non-negotiable boundaries

Only the scanner/client user authenticates, automatically and anonymously.
There is no admin/reviewer app role or dashboard. The backend service account is
a machine credential. Firebase Unlabel's first Standard database unlabel in
Mumbai keeps its free tier, deny-all client rules and no linked billing.
No paid Storage/Functions, TTL, backups or PITR may be added.

Preserve original rows/units/table bases, uncertainty and source receipts. Missing
is not zero, allergy-safe or compliance proof. Claim checks retain their numerical
scope and cited inputs; unsupported protein/no-added-sugar/multigrain claims remain
insufficient. Gemini is disabled and custom training is unselected.

Before each push, review docs/scripts/tests, meaningful process/import/secret
boundaries and current contract exports. Never commit plaintext environment,
private identities, real scans or credentials. Keep backend and frontend tags/
validation independent and do not rebuild native artifacts for backend work.

[System](../architecture/SYSTEM.md) · [Data flow](../architecture/DATA_FLOW.md) ·
[Folders](../architecture/FOLDER_STRUCTURE.md) · [Features](FEATURES.md) ·
[Feature tracker](FEATURE_TRACKER.md) · [Contracts](../../contracts/README.md)
