# Working on the Unlabel foundation

The current phase includes Flutter v0.0.0, backend v0.2.2 live APIs and a verified catalogue bundle, shared contracts/docs, manual mobile releases and Vercel setup. Restore a clone with the [local development guide](docs/planning/LOCAL_DEVELOPMENT.md). Follow the [version plan](docs/superpowers/plans/2026-10-05-backend-versions.md), one backend version at a time. Flutter features belong to the teammate. Keep ₹0/no-card and update docs before every push.

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

## Future validation

Implementation should test meaningful unit normalization, claim-rule applicability, allergens, evidence references, API shape and provider failures. Camera/OCR and overlay geometry require physical Android-device checks. Build success alone will not prove OCR accuracy or food safety.

Track application lockfiles. Do not add fake backend code, source data or test placeholders that suggest the food-analysis features already run. Use the manual workflow for version-aligned demo artifacts; never describe unsigned iOS as directly installable.
