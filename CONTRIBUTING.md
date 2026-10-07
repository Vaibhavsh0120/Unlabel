# Working on the Unlabel foundation

Published backend is **v0.5.0 Useful Label Report**, Flutter **0.0.0+1**.
Its source, report and hosted checks passed before separate publication after v0.4.0; the configured free Firebase resources are unchanged. Follow the [master architecture](docs/planning/MASTER_PLAN.md).
Latest direction automatically saves confirmed public facts and stages unverified
candidates. Preserve the released OFF/claim foundation and [current release gates](docs/planning/BACKEND_V0_5_0_REVIEW.md).
Keep ₹0/no-card, review Markdown/scripts and update docs before a future push.

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
