# Teammate handoff

Current review checkpoint (8 October 2026): backend **v0.9.0** is pushed and
READY with **26 hosted checks**; frontend **v0.4.0+5** passes **181 tests**,
analysis, release web build and synthetic browser workflow checks. Its
independent push/deployment verification is the remaining release gate.
[Backend review](BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](FRONTEND_V0_4_0_REVIEW.md).

Restore from root with python scripts/setup.py and run with
python scripts/run_local.py; PowerShell wrappers remain available.
Setup preserves local settings, can restore encrypted backend/.env.age, verifies
the tracked India source and builds the current discovery index with progress.
[Recovery guide](LOCAL_DEVELOPMENT.md).

## Current checkpoint

Latest checkpoint: frontend v0.3.0+4 is published/hosted-verified; backend v0.8.0 is pushed/hosted-verified with 25 checks. Current v0.4.0+5/v0.9.0 work and its independent evidence live in the [implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md) and [tracker](FEATURE_TRACKER.md). Earlier release identities below remain preserved.

Backend **v0.6.0 Product Discovery** and frontend **v0.1.0+2 Connected Label Reader**
are independently pushed, hosted-verified and published. Frontend source commit
`1138c292296ae6c9309d73d430d267ec1a98fa80` passed production asset/browser checks.
Backend **v0.7.0 Private Account Sync** is independently pushed, hosted-verified
and published: **931 tests passed, five emulator-only skips**, clean Ruff/Pyright,
18 hosted synthetic checks and 13 fresh read-only hosted checks. The source tag
preserves implementation SHA `9d9a9b64a735bd1ad6fdd606c82e0a34412dd6f0`.
Frontend **v0.2.0+3 Welcome, Home and Optional Account** is published from
`5f3e92fe58f87aeed6a78f989b3f9289233ca2f2`; 135 tests, clean analysis, hosted
asset/API checks and the source release passed. The native workflow is separate.
Guests keep personal data locally; optional password sign-in enables private
account profile/saved/history sync. Public package facts remain separate.
[Current account checklist](ACCOUNT_SYNC_SCREEN_PLAN.md) ·
[Private architecture](../architecture/PRIVATE_ACCOUNT_SYNC.md).

Historical production **v0.5.0 Useful Label Report** and **v0.4.0 Community Product Catalogue**
were independently pushed, hosted-verified and published. Preserve their source
tags and evidence: [v0.5.0 proof](../research/BACKEND_V0_5_0_PRODUCTION.json),
[v0.4.0 proof](../research/BACKEND_V0_4_0_PRODUCTION.json).
Earlier review/test counts are historical, not the next release's hosted proof.

Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app).
API: [unlabel-api.vercel.app](https://unlabel-api.vercel.app).
[Deployment configuration](VERCEL_SETUP.md).

Implemented backend v0.7.0/frontend v0.2.0 adds optional private account sync,
Welcome/Home and four-tab navigation with top-right Profile. Finish their independent release gates
before frontend v0.3.0 adds local OCR/barcode decoding and Ingredient Insights. Guests
retain local features; public package facts remain separate. [Version checklist](ACCOUNT_SYNC_SCREEN_PLAN.md).

## What the person can do

The Flutter home opens manual barcode lookup or bounded name/brand search.
Candidates show identifying fields and require explicit selection. The historical
report preserves source dates, unavailable facts and conflicts.

The dedicated label form accepts the current package's identity, claims,
ingredient/allergen declarations and nutrient rows with printed basis/unit/
preparation. Independent confirmation/pairing precedes analysis. An unchanged
retry keeps its submission ID; changing facts creates a fresh submission.
Structured public facts save automatically through anonymous guest or password scanner Auth.
Storage/auth failures are distinct from the useful report outcome.

Reports show sourced current/historical facts, approximate original-basis sugar
cubes, the reviewed numerical claim subset and six reviewed English/Hindi ingredient
functions. The person can explicitly bookmark a report and reopen bounded private
device-local saved/history lists. Appearance uses the owner's white/forest/mint
direction, real Material 3 controls and locally licensed Solar icons.

Basic camera/gallery capture and manual review are included in v0.2.0. Local OCR,
automatic barcode decoding, dietary suitability, AI calls, training and fake 85/100
scores remain outside it. Reference reports, client comparison and sourced educational
destinations are implemented and locally tested. Native device validation remains
separate from the web/widget checks.

## Integration and ownership

| Area | Current implementation |
| --- | --- |
| Client composition | frontend/lib/app, one Flutter app for Android/iOS/web |
| Client data | core/models/network/storage/accounts: bounded HTTP, metadata handshake, SDK-owned anonymous/password Auth, isolated guest/account libraries and private CAS sync |
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

Only the scanner/client user authenticates: guests use automatic anonymous public-write
identity; optional password sign-in enables separate private profile/saved/history sync.
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
