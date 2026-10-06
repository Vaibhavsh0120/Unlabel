# Teammate handoff

Fresh clone: `./scripts/setup.ps1`, then `./scripts/run-local.ps1` from root. Setup preserves `.env` or offers key-file/hidden-paste/example restoration, verifies the committed India source and regenerates SQLite. Python equivalents support macOS/Linux. [Recovery guide](LOCAL_DEVELOPMENT.md) · [Supplied concepts](../../design/references/README.md).

> Unlabel has a Flutter v0.0.0+1 starter and FastAPI backend v0.2.3 product/nutrition lookup, confirmed-value normalization and a verified India catalogue/status with separate rich-facts contracts. Both Vercel projects are configured for automatic `main` deployments. Camera/OCR, health scores and FSSAI claim checks remain future work.

Website: **[unlabel-india.vercel.app](https://unlabel-india.vercel.app)**. API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)**. [Hosting settings/verification](VERCEL_SETUP.md).

## What exists

- Flutter/native/web scaffold, appearance selection, lockfile and layout/theme/large-text tests.
- Runnable stateless backend, strict exported contracts/synthetic examples, and reserved knowledge/design/AI folders.
- Data/API/offline/deployment/release plans and checked provider/source research.
- Manual build/checksum/manifest/release workflow and v0.0.0 app version.

Backend v0.2.3 exposes eight routes: health, metadata, product lookup, separate nutrition lookup, POST normalization of confirmed nutrient rows, typed catalogue status, exact catalogue identity lookup and separate rich facts. Frontend stays v0.0.0+1 and has no API adapter yet. No OCR plugin, rule engine or trained model has been added. The tracked India source rebuilds local SQLite and a separate hosted SQLite/receipt without another export download. Hosted activation requires receipt/hash/manifest/integrity/count checks; [release-specific validation](BACKEND_V0_2_3_REVIEW.md) records measured-source/local/actual deployment gates separately. No API key is required. See the [backend guide](../../backend/README.md) and [version plan](../superpowers/plans/2026-10-05-backend-versions.md).

| Topic | Direction |
| --- | --- |
| Frontend | Single Flutter app directly frontend; Android/iOS/web |
| UI | iPhone/iPad orientations/MacBook; light/dark; palette undecided |
| Backend | Python/FastAPI, separate configured Vercel project |
| Evidence | OFF and user-confirmed origins remain separate; reviewed FSSAI criteria are later work |
| Product data | Source-tagged live OFF product/nutrition routes plus separate export-origin identity/facts catalogue; no silent origin fallback |
| Offline | Saved dated reports/snapshots, preferences and optional glossary; new analysis needs backend |
| Rules | Python will apply reviewed FSSAI/evidence criteria; no second Dart rule engine; no legal certification |
| AI | Optional wording; training/HF only if separately useful/eligible |
| Storage | Device/browser local history/preferences; server stateless |
| Releases | Native APK/IPA share source/frontend version/build; backend versions are independent; unsigned IPA is not installable |

Start the next meeting with [system](../architecture/SYSTEM.md), [data flow](../architecture/DATA_FLOW.md), [folders](../architecture/FOLDER_STRUCTURE.md), [features](FEATURES.md) and [API](../architecture/API_PLAN.md). Choose a small source/claim scope, validate OCR, freeze compatibility/coverage, and assign owners before the next requested phase.

The teammate can build against the exported [contracts](../../contracts/README.md) and synthetic examples without a provider key. Keep v1 identity parsing unchanged and add separate nutrition/facts models. Check `catalogue_facts` before using the facts route. Render direct-table availability, tags with availability, optional dates/image attribution and unknown values; an image descriptor alone is not proof the remote image currently loads. The confirmed-input body requires real boolean `confirmed: true`, UUID request/session IDs, a revision, completeness, and 1–64 rows; the actual body budget is 32 KiB. Preserve `original_rows`, table sources/preparation/bases, unknown-cell reasons, and all warnings. A `complete` normalization status does not mean every nutrient is known or that a food is healthy. Reject stale responses by request/session/revision.

The app must not silently combine OFF tables with user-confirmed values, infer missing added sugar/salt, or compare mass and volume. Unknown serving size stays per serving. Saved results, offline caching, camera/OCR and charts remain teammate work. Catalogue status identifies limits for the actual loaded store, missing allergen uncertainty and nine-calendar-month source age; snapshot misses make no OFF request. Rich facts distinguish direct, missing, invalid and unsupported legacy nutrition. Present empty community tags never prove allergen absence. Full JSONL acquisition is complete: 24,695 India rows, 24,641 supported unique codes and validated gzip EOF; source **2026-10-06T06:53:46Z** is due **2027-07-06T06:53:46Z**. All 24,641 supported facts validate; the local build verifies a 62,472,192-byte SQLite/receipt. Only 4,519 records contain reported direct nutrient values; render sparse facts/legacy-unsupported states without inventing values. Hosted v0.2.3 facts/identity reads and build/public receipt agreement passed for the independently pushed implementation; [dated production proof](../research/BACKEND_V0_2_3_PRODUCTION.json). coverage remains unverified. The [OFF workflow](../architecture/OPEN_FOOD_FACTS.md) explains current adapters; the [catalogue guide](../architecture/CATALOGUE.md) documents immutable deployment replacement/rollback. The v0.2.3 independent source push, tested tag and hosted gate are complete; v0.3.0 is the next separate reviewed-claims release. Camera/OCR, report scoring, saved/history/preferences and comparison still require their tracked integration work. [20-group tracker](FEATURE_TRACKER.md). [Roadmap](ROADMAP.md) and [contribution rules](../../CONTRIBUTING.md) cover later work.
