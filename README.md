<div align="center">

# Unlabel

### Label Padhega India

**Understand the label. Know what is inside.**

![Frontend](https://img.shields.io/badge/frontend-0.2.0-155b4b?style=flat-square)
![Backend](https://img.shields.io/badge/backend-0.7.0-155b4b?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.47.4-59636e?style=flat-square)
![Targets](https://img.shields.io/badge/targets-Android%20%C2%B7%20iOS%20%C2%B7%20Web-59636e?style=flat-square)

[Website](https://unlabel-india.vercel.app) · [API](https://unlabel-api.vercel.app/v1/meta) · [API docs](https://unlabel-api.vercel.app/docs)

</div>

Unlabel helps people read Indian packaged-food labels using sourced facts,
reviewed claim checks and clear missing-information states. The app uses a
white, forest-green and mint design, with light as the first-use default.

## What works

**Backend v0.6.0 and frontend v0.1.0+2 are independently published.**
**Backend v0.7.0 Private Account Sync is implemented and ready to push; hosted
verification remains pending. Frontend v0.2.0 Welcome, Home and Optional Login is
implemented with release validation pending.**
[Version checklists](docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md).

- Enter a barcode or search name/brand words and choose an exact catalogue record.
- Read dated historical reports, nutrition bases, source references and unknowns.
- Enter and confirm current package facts for a separate useful label report.
- See approximate total-sugar cubes, seven reviewed numerical claim types and
  three reviewed English/Hindi ingredient functions where evidence permits.
- Continue as a guest with device-local saved reports/history, or optionally sign in
  to sync a private account display name, saved reports and history across devices.
- Use first-launch Welcome, light/dark Home and Home/Scan/Compare/Saved/Profile navigation;
  v0.2.0 working destinations await their full release validation.
- Save confirmed public package facts automatically to improve the shared catalogue.

Guests do not upload personal history or saved lists. Password accounts use a
separate verified-UID namespace and private CAS sync, with explicit cloud/device
replacement choices. Appearance and Welcome completion stay on the device; photos,
raw OCR and dietary health preferences are excluded from private sync. Public facts
use anonymous or signed-in scanner authentication; there are no admin/reviewer app accounts. Storage failure does not discard
the useful report. [Privacy and evidence](docs/SAFETY_PRIVACY.md).

Camera/gallery OCR, live highlights, personal suitability, wider reviewed insight
coverage and the remaining reference-style results screens stay tracked. v0.2.0
adds compatible-basis client comparison and sourced educational destinations;
their rendered/release validation remains pending. Concept-image scores are illustrative;
the app does not invent a universal health or allergy-safety verdict.
[20-group feature tracker](docs/planning/FEATURE_TRACKER.md).

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
| Reviewed ingredient glossary | Three technological-function entries in English/Hindi |

Generic IFCT/INDB/USDA food composition does not fill a branded packet's unknown
values. Missing is unknown, not zero. Tables retain basis and preparation; source
conflicts are preserved. Sugar cubes use the explicit approximate 4 g/cube policy.
No custom model/training is selected; Gemini remains disabled.

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
· [Community catalogue](docs/architecture/COMMUNITY_CATALOGUE.md).

## Validation and releases

Backend v0.7.0: **931 passed, five emulator-only skips**, clean Ruff/Pyright and
**18 live synthetic checks** using a local API with real Firebase; hosted/publication
checks remain pending. [Review](docs/planning/BACKEND_V0_7_0_REVIEW.md).
Frontend v0.1.0+2: independently published at exact source
`1138c292296ae6c9309d73d430d267ec1a98fa80`, with production assets/browser checks.
[Production proof](docs/research/FRONTEND_V0_1_0_PRODUCTION.json).
Frontend v0.2.0: implemented; **25 focused account tests** pass, while full
render/build/push/hosted validation remains pending. [Frontend guide](frontend/README.md).

Vercel deploys separate backend/web projects from `main`. Backend source tags
remain `v0.x.0`; frontend source uses `frontend-v0.1.0`; future manual mobile
builds use `mobile-vVERSION+BUILD`. Existing tags and assets are preserved.

The manual APK/unsigned-IPA workflow uses one immutable commit and matching
version/build. It is not triggered by these backend/web releases. APKs use demo
signing; the unsigned IPA is not directly installable. Native build/device gates
are separate from Flutter/web checks. [Release guide](docs/planning/RELEASE_VERSIONING.md)
· [Deployment settings](docs/planning/VERCEL_SETUP.md).

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
