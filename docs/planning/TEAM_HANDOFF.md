# Teammate handoff

Fresh clone: `./scripts/setup.ps1`, then `./scripts/run-local.ps1` from root. Setup preserves `.env` or offers key-file/hidden-paste/example restoration, verifies the committed India source and regenerates SQLite. Python equivalents support macOS/Linux. [Recovery guide](LOCAL_DEVELOPMENT.md) · [Supplied concepts](../../design/references/README.md).

> Unlabel has a Flutter v0.0.0 starter and FastAPI backend v0.2.1 product/nutrition lookup plus confirmed-value normalization. Both Vercel projects are configured for automatic `main` deployments. Camera/OCR, health scores and FSSAI claim checks remain future work.

Website: **[unlabel-india.vercel.app](https://unlabel-india.vercel.app)**. API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)**. [Hosting settings/verification](VERCEL_SETUP.md).

## What exists

- Flutter/native/web scaffold, appearance selection, lockfile and layout/theme/large-text tests.
- Runnable stateless backend, strict exported contracts/synthetic examples, and reserved knowledge/design/AI folders.
- Data/API/offline/deployment/release plans and checked provider/source research.
- Manual build/checksum/manifest/release workflow and v0.0.0 app version.

Backend v0.2.1 exposes six routes: health, metadata, product lookup, separate nutrition lookup, and POST normalization of confirmed nutrient rows, and optional separate indexed catalogue lookup. Frontend stays v0.0.0 and has no API adapter yet. No OCR plugin, rule engine or trained model has been added. A local India identity catalogue was acquired/indexed; its compact source is tracked for clone recovery; generated SQLite is ignored and not yet packaged for Vercel. No API key is required. See the [backend guide](../../backend/README.md), [version plan](../superpowers/plans/2026-10-05-backend-versions.md) and release-specific [validation record](BACKEND_V0_2_1_REVIEW.md).

| Topic | Direction |
| --- | --- |
| Frontend | Single Flutter app directly frontend; Android/iOS/web |
| UI | iPhone/iPad orientations/MacBook; light/dark; palette undecided |
| Backend | Python/FastAPI, separate configured Vercel project |
| Evidence | OFF and user-confirmed origins remain separate; reviewed FSSAI criteria are later work |
| Product data | Open Food Facts does primary online product-data lookup through FastAPI; source-tagged facts/insights |
| Offline | Saved dated reports/snapshots, preferences and optional glossary; new analysis needs backend |
| Rules | Python will apply reviewed FSSAI/evidence criteria; no second Dart rule engine; no legal certification |
| AI | Optional wording; training/HF only if separately useful/eligible |
| Storage | Device/browser local history/preferences; server stateless |
| Releases | Native APK/IPA share source/frontend version/build; backend versions are independent; unsigned IPA is not installable |

Start the next meeting with [system](../architecture/SYSTEM.md), [data flow](../architecture/DATA_FLOW.md), [folders](../architecture/FOLDER_STRUCTURE.md), [features](FEATURES.md) and [API](../architecture/API_PLAN.md). Choose a small source/claim scope, validate OCR, freeze compatibility/coverage, and assign owners before the next requested phase.

The teammate can build against the exported [contracts](../../contracts/README.md) and synthetic examples without a provider key. Keep v1 product parsing unchanged and add separate nutrition models. The confirmed-input body requires real boolean `confirmed: true`, UUID request/session IDs, a revision, completeness, and 1–64 rows; the actual body budget is 32 KiB. Preserve `original_rows`, table sources/preparation/bases, unknown-cell reasons, and all warnings. A `complete` normalization status does not mean every nutrient is known or that a food is healthy. Reject stale responses by request/session/revision.

The app must not silently combine OFF tables with user-confirmed values, infer missing added sugar/salt, or compare mass and volume. Unknown serving size stays per serving. Saved results, offline caching, camera/OCR and charts remain teammate work. The [OFF workflow](../architecture/OPEN_FOOD_FACTS.md) explains current adapter limits; the [snapshot proposal](../research/INDIA_SNAPSHOT.md) documents manual nine-month replacement and the separate v0.2.2 hosting gate. [Roadmap](ROADMAP.md) and [contribution rules](../../CONTRIBUTING.md) cover later work.
