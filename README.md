<div align="center">

# Unlabel

### Label Padhega India

**Understand the label. Know what is inside.**

![Frontend](https://img.shields.io/badge/frontend-0.7.0-155b4b?style=flat-square)
![Backend](https://img.shields.io/badge/backend-0.12.0-155b4b?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.47.4-59636e?style=flat-square)
![Targets](https://img.shields.io/badge/targets-Android%20%C2%B7%20iOS%20%C2%B7%20Web-59636e?style=flat-square)

[Website](https://unlabel-india.vercel.app) · [API](https://unlabel-api.vercel.app/v1/meta) · [API docs](https://unlabel-api.vercel.app/docs)

</div>

Unlabel helps people read Indian packaged-food labels using sourced facts,
reviewed claim checks and clear missing-information states. The app uses a
white, forest-green and mint design, with light as the first-use default.

## Latest Update

**Frontend v0.7.0+11 · Backend v0.12.0**

- 20 sourced insights with unique artwork and four daily picks shared with Home.
- Full articles, topic filters and bookmarks saved on your device.
- PC/mobile swipe, dots and keyboard controls, plus distinct preference and allergen symbols.

[Insights review](docs/planning/FRONTEND_V0_7_0_REVIEW.md) ·
[Feature tracker](docs/planning/FEATURE_TRACKER.md).

Maintenance on 12 October fixes stale setup/docs, release metadata and native
build workflows without changing versions. Versions now have one canonical file
per component. [Audit and checks](docs/planning/MAINTENANCE_2026_10_12.md) ·
[Source release ledger](docs/planning/CONTROLLED_RELEASES.md).

## Clone and run

Install Git and Python 3.12+, then run from the project folder:

~~~powershell
./scripts/setup.ps1
./scripts/run-local.ps1
~~~

macOS/Linux: `python3 scripts/setup.py`, then `python3 scripts/run_local.py`.
Setup restores dependencies, settings and verified product data with progress
indicators. Use a key file, hidden key paste or safe defaults; never commit `.env`.
`--scope backend` or `--scope frontend` selects one component.

| Local service | Address |
| --- | --- |
| Website | http://127.0.0.1:7357 |
| API docs | http://127.0.0.1:8000/docs |

The runner supplies local CORS, catalogue and version settings through process
overrides. Production clients use `https://unlabel-api.vercel.app`.
[Local development and encryption](docs/planning/LOCAL_DEVELOPMENT.md).

## Data and architecture

The acquired India-tagged OFF snapshot contains **24,641 supported barcodes**.
The generated discovery-enabled SQLite bundle is **72.58 MiB**. Retail/regional
coverage remains unmeasured. Exact and search misses do not silently call OFF;
separate live product/nutrition APIs remain available.

| Source | Purpose |
| --- | --- |
| Open Food Facts | Dated packaged-product identity and available direct label facts |
| Confirmed package observations | Qualified compatible gap fills, original sources/dates and visible conflicts |
| Reviewed FSSAI knowledge | Seven scoped numerical claim checks with sufficient confirmed inputs |
| Reviewed ingredient glossary | Six technological-function entries; partial coverage in English/Hindi |

Generic IFCT/INDB/USDA food composition does not fill a branded packet's unknown
values. Missing is unknown, not zero. Tables retain basis and preparation; source
conflicts are preserved. Sugar cubes use the explicit approximate 4 g/cube policy.
No custom model/training is selected. Optional Gemini/OpenAI extraction uses one
globally active server credential with sticky manual/failure replacement.

Backend v0.12.0 retains the original SQLite data, extends the research index with
ingredient/declaration/claim terms and attaches **120 sourced image descriptors
to 243 research observations**; 123 still lack an image. Unverified structured AI
facts use bounded private Firestore staging, separate from public admission and
personal sync. Decorative artwork never fills missing product-image evidence.

Firebase **Unlabel**, project `unlabel-india-catalogue`, uses its first Standard
database **unlabel** in Mumbai with free tier/no linked billing. Deny-all client
rules and backend credentials protect separate public observations and private
account snapshots. Anonymous and email/password sign-in are configured. No paid
Storage/Functions, billing upgrade or card is required.

New lookup/analysis needs the backend. Already loaded dated reports can be read
from local storage; website first-load/offline app-shell caching is not promised.
Shared preferences are convenience storage, not an encrypted backup.

[Master plan](docs/planning/MASTER_PLAN.md) · [Data flow](docs/architecture/DATA_FLOW.md)
· [Discovery](docs/architecture/PRODUCT_DISCOVERY.md) · [Reports](docs/architecture/LABEL_REPORT.md)
· [Community catalogue](docs/architecture/COMMUNITY_CATALOGUE.md)
· [Privacy and evidence](docs/SAFETY_PRIVACY.md) · [AI routing](docs/architecture/AI_ROUTING.md).

## Validation and releases

The maintenance frontend passed **268 tests**, clean analysis and a production web
build. Native build/publication and physical-device evidence remain separate.
Backend v0.12.0 is unchanged, with **389 hosted checks** recorded on 8 October.
[Frontend review](docs/planning/FRONTEND_V0_7_0_REVIEW.md) ·
[Backend review](docs/planning/BACKEND_V0_12_0_REVIEW.md).

Vercel deploys the web app and API separately from `main`. Mobile builds run
through the manual workflow and require separate native/device validation.
[Release guide](docs/planning/RELEASE_VERSIONING.md) ·
[Deployment settings](docs/planning/VERCEL_SETUP.md).

For iOS, add this URL in **LiveContainer → Sources → +**:

[Unlabel LiveContainer source](https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json)

The source becomes available after the verified native release publishes. It lists
the unsigned iPhoneOS IPA; LiveContainer must already be installed and configured.
Actual iPhone import and launch require a device check.

## Repository and team

| Folder | Responsibility |
| --- | --- |
| frontend | Flutter app, platform icons, UI, bounded API and local persistence |
| backend | FastAPI, catalogue, reviewed checks and report composition |
| contracts | Versioned schemas, historical OpenAPI and synthetic fixtures |
| data / knowledge | Reusable licensed source bundles, provenance and reviewed rules |
| scripts | Restore/run/encryption/import/export and verified icon generation |
| docs / design | Architecture, release evidence, progress and supplied UI references |

[Teammate handoff](docs/planning/TEAM_HANDOFF.md) · [Folder guide](docs/architecture/FOLDER_STRUCTURE.md)
· [UI requirements](docs/planning/UI_REQUIREMENTS.md) · [Contributing](CONTRIBUTING.md).
Keep plaintext credentials, private identities and real scans out of Git.
