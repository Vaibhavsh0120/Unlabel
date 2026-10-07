<div align="center">

# Unlabel

### Label Padhega India

**Understand the label. Know what is inside.**

![Frontend](https://img.shields.io/badge/frontend-0.3.0-155b4b?style=flat-square)
![Backend](https://img.shields.io/badge/backend-0.7.0-155b4b?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.47.4-59636e?style=flat-square)
![Targets](https://img.shields.io/badge/targets-Android%20%C2%B7%20iOS%20%C2%B7%20Web-59636e?style=flat-square)

[Website](https://unlabel-india.vercel.app) · [API](https://unlabel-api.vercel.app/v1/meta) · [API docs](https://unlabel-api.vercel.app/docs)

</div>

Unlabel helps people read Indian packaged-food labels using sourced facts,
reviewed claim checks and clear missing-information states. The app uses a
white, forest-green and mint design, with light as the first-use default.

## What works

**Frontend v0.3.0+4 Visual Label Reader and backend v0.7.0 Private Account Sync
are independently published and hosted-verified.** Frontend source
`3f9a8172c284c74e25c0c83a270c1e8cabc26bdb` passed 49 hosted checks and browser
Welcome/search checks. Backend **v0.8.0 Sourced Nutrient Comparison** is separately
implemented and locally verified; its push, hosted verification and publication
are the next release gates. The frontend does not require that endpoint.
Historical releases remain preserved.
[Version checklists](docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md).

- Enter a barcode or search name/brand words and choose an exact catalogue record.
- Read dated historical reports, nutrition bases, source references and unknowns.
- Enter and confirm current package facts for a separate useful label report.
- See approximate total-sugar cubes, seven reviewed numerical claim types and
  three reviewed English/Hindi ingredient functions where evidence permits.
- Continue as a guest with device-local saved reports/history, or optionally sign in
  to sync a private account display name, saved reports and history across devices.
- Use responsive botanical Welcome on mobile and PC, compact light/dark Home and
  the existing floating Home/Scan/Compare/Saved navigation, with Profile at the top right.
- Capture a private camera/gallery photo, read English/Hindi text locally, correct
  suggested label fields and explicitly confirm facts before analysis. Nutrition
  tables remain manually reviewed. Manual barcode fallback lives inside Scan Label.
- Open a reference-style Profile with actual library counts, optional account
  editing/sync, local reminders, appearance, privacy and help controls.
- Save confirmed public package facts automatically to improve the shared catalogue.

Guests do not upload personal history or saved lists. Password accounts use a
separate verified-UID namespace and private CAS sync, with explicit cloud/device
replacement choices. Appearance and Welcome completion stay on the device; photos,
raw OCR and dietary health preferences are excluded from private sync. Public facts
use anonymous or signed-in scanner authentication; there are no admin/reviewer app accounts. Storage failure does not discard
the useful report. [Privacy and evidence](docs/SAFETY_PRIVACY.md).

v0.3.0 adds an app-only startup screen; the website has no branded loading screen.
Home Search requests keyboard focus on tap. Search uses accessible skeletons,
bounded public-read caching and limited background thumbnail requests. The Scan
Label layout and four-tab navigation design/order remain the established ones;
the bar sits lower and its active icon can be held and dragged.

Automatic barcode camera detection, continuous live highlights, personal
suitability and wider reviewed insight coverage remain future work. Profile
notifications are explicitly unavailable, and unrecorded comparison totals show
an unknown count. Saved dietary/allergen choices are device-local reminders;
they do not filter products or establish allergy safety. v0.2.0 introduced live
header search, reference-style reports, compatible-basis client comparison and manually swiped tips.
Concept-image scores are illustrative;
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

Backend v0.7.0: **931 passed, five emulator-only skips**, clean Ruff/Pyright,
18 hosted synthetic checks and 13 fresh read-only checks. [Review](docs/planning/BACKEND_V0_7_0_REVIEW.md).
Frontend v0.1.0+2: independently published at exact source
`1138c292296ae6c9309d73d430d267ec1a98fa80`, with production assets/browser checks.
[Production proof](docs/research/FRONTEND_V0_1_0_PRODUCTION.json).
Frontend v0.2.0+3: **135 tests passed**, clean analysis, web build and hosted
asset/API checks; source release is published. [Frontend proof](docs/research/FRONTEND_V0_2_0_PRODUCTION.json).
Frontend v0.3.0+4: **168 Flutter tests passed**, clean analysis, four browser OCR
bridge tests and pinned-asset verification. A real local browser read a synthetic
label using the bundled OCR engine. Release web build and light-mode checks at
390/1440/1728 pixels passed. Exact source
`3f9a8172c284c74e25c0c83a270c1e8cabc26bdb` is published as
[frontend-v0.3.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0),
with READY deployment `dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`, 49 hosted checks and all
21 OCR asset hashes verified. Hosted Welcome enters Home; Search focuses an actual
input and returns ten results from 57 matches.
[Production receipt](docs/research/FRONTEND_V0_3_0_PRODUCTION.json) ·
[Current review](docs/planning/FRONTEND_V0_3_0_REVIEW.md).

Vercel deploys separate backend/web projects from `main`. Backend source tags
remain `v0.x.0`; frontend source uses `frontend-vVERSION`; future manual mobile
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
