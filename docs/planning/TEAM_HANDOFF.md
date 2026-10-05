# Teammate handoff

> Unlabel has a Flutter v0.0.0 starter and FastAPI backend v0.1.0 product lookup. Both Vercel projects are configured for automatic `main` deployments. Core scanning and food analysis are not implemented yet.

Website: **[unlabel-india.vercel.app](https://unlabel-india.vercel.app)**. API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)**. [Hosting settings/verification](VERCEL_SETUP.md).

## What exists

- Flutter/native/web scaffold, appearance selection, lockfile and layout/theme/large-text tests.
- Reserved backend, knowledge, contracts, fixtures, design and optional AI folders.
- Data/API/offline/deployment/release plans and checked provider/source research.
- Manual build/checksum/manifest/release workflow and v0.0.0 app version.

Backend v0.1.0 implements health/meta and live OFF barcode lookup; frontend stays v0.0.0. No OCR plugin, rule engine, corpus or trained model has been added. Provider secrets are unnecessary for OFF reads. See the [backend version plan](../superpowers/plans/2026-10-05-backend-versions.md) and [validation record](BACKEND_V0_1_0_REVIEW.md).

| Topic | Direction |
| --- | --- |
| Frontend | Single Flutter app directly frontend; Android/iOS/web |
| UI | iPhone/iPad orientations/MacBook; light/dark; palette undecided |
| Backend | Python/FastAPI, separate configured Vercel project |
| Evidence | Confirmed package first; reviewed FSSAI/public sources for criteria |
| Product data | Open Food Facts does primary online product-data lookup through FastAPI; source-tagged facts/insights |
| Offline | Saved dated reports/snapshots, preferences and optional glossary; new analysis needs backend |
| Rules | Python applies reviewed FSSAI/evidence criteria; no second Dart rule engine; no legal certification |
| AI | Optional wording; training/HF only if separately useful/eligible |
| Storage | Device/browser local history/preferences; server stateless |
| Releases | Native APK/IPA share source/frontend version/build; backend versions are independent; unsigned IPA is not installable |

Start the next meeting with [system](../architecture/SYSTEM.md), [data flow](../architecture/DATA_FLOW.md), [folders](../architecture/FOLDER_STRUCTURE.md), [features](FEATURES.md) and [API](../architecture/API_PLAN.md). Choose a small source/claim scope, validate OCR, freeze compatibility/coverage, and assign owners before the next requested phase.

No key is needed for the starter or public OFF lookup. The teammate can use the implemented product route and exported [contracts](../../contracts/README.md); the Flutter API adapter is still their future work. The [OFF workflow](../architecture/OPEN_FOOD_FACTS.md) covers later nutrition, caching and analysis, and the [snapshot proposal](../research/INDIA_SNAPSHOT.md) records the planned six-month replacement. [Roadmap](ROADMAP.md) and [contribution rules](../../CONTRIBUTING.md) cover later work.
