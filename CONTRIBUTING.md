# Working on Unlabel

Updated **8 October 2026**. Frontend v0.3.0+4 is independently published
and hosted-verified; backend v0.8.0 is pushed and hosted-verified at exact
implementation `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` with 25 checks.
Its source-release publication is not established by that receipt.
Current work is backend v0.9.0 Reviewed Ingredient Functions and frontend
v0.4.0+5 Sourced Comparison and Ingredient Detail. Independent review, tests,
push and hosted evidence are recorded in the current component reviews.
Guests keep personal records local; optional password accounts use private
UID-specific sync, separately from public package facts. Capture/local OCR
are implemented; physical-device accuracy, live barcode decoding, highlights,
notifications and personal suitability remain separate future gates.

Work directly on main, preserve teammate edits, review each component separately
and update documentation before each authorized push. Keep ₹0/no-card and
follow [controlled releases](docs/planning/CONTROLLED_RELEASES.md).

## Team boundaries

- Android/iOS/web work belongs in the single Flutter frontend. Primary Open Food Facts product lookup and reviewed rule evaluation belong in backend. The MVP is online-first; limited offline saved results/preferences/glossary do not require a second rule engine in frontend/lib/core/analysis.
- Reviewed ingredient/rule/source content belongs in knowledge. Shared contract definitions belong in contracts. Shared test fixtures belong in data/fixtures.
- Agree on the API contract, missing-value behavior and evidence IDs before frontend/backend work starts in parallel.
- Preserve others' changes; keep one shared contract owner. Split changes by feature or responsibility.
- Update architecture and handoff documents when an accepted decision changes.

## Data and secrets

- Never commit plaintext API keys, private age identities, allergy profiles, scan history, runtime databases or unreviewed downloads. Tracked `backend/.env.age` is authenticated ciphertext; refresh it with `python scripts/env.py encrypt` after changing local settings. Public recipient data is safe to track.
- Keep reviewed reusable acquired source bundles, hashes, provenance and licenses in Git. The India source lives in data/catalogue; setup regenerates SQLite. Retain attribution and unknown/coverage semantics.
- backend/.env.example documents active public settings and reserved AI fields. Real values belong in the ignored backend/.env file; preserve existing values.
- Do not put Gemini keys into the mobile app, its assets, build arguments or client-side environment files.
- Fixtures must be synthetic or explicitly reusable, with source/rights recorded. Legal thresholds need a reviewed source, effective date and food-category applicability.
- Never turn unknown or missing data into zero, a passed claim or an allergy-safe verdict.
- Confirmed public product facts save/deduplicate automatically through the v0.4.0 API, with unverified extraction candidates staged separately and anonymous writes behind the scenes. No separate Share action. Preserve original observations; complement compatible fields only with per-field source/date and visible conflicts. Generic composition never fills packet gaps.
- Firebase Unlabel has its first Standard database `unlabel` in Mumbai, free tier enabled and no linked billing. No paid fallback, Storage/Functions, TTL, backups or PITR. Photos/raw OCR/profiles/history stay private. [Storage boundaries](docs/architecture/COMMUNITY_CATALOGUE.md).

## Future validation

Implementation should test meaningful unit normalization, claim-rule applicability, allergens, evidence references, API shape and provider failures. Camera/OCR and overlay geometry require physical Android-device checks. Build success alone will not prove OCR accuracy or food safety.

Track application lockfiles. Do not add fake backend code, source data or test placeholders that suggest the food-analysis features already run. Use the manual workflow for version-aligned demo artifacts; never describe unsigned iOS as directly installable.
