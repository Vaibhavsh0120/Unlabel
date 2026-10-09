<div align="center">

# Unlabel

### Label Padhega India

**Understand the label. Know what is inside.**

![Frontend](https://img.shields.io/badge/frontend-0.6.2-155b4b?style=flat-square)
![Backend](https://img.shields.io/badge/backend-0.12.0-155b4b?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.47.4-59636e?style=flat-square)
![Targets](https://img.shields.io/badge/targets-Android%20%C2%B7%20iOS%20%C2%B7%20Web-59636e?style=flat-square)

[Website](https://unlabel-india.vercel.app) · [API](https://unlabel-api.vercel.app/v1/meta) · [API docs](https://unlabel-api.vercel.app/docs)

</div>

Unlabel helps people read Indian packaged-food labels using sourced facts,
reviewed claim checks and clear missing-information states. The app uses a
white, forest-green and mint design, with light as the first-use default.

## What works

Frontend **v0.7.0+11** adds twenty sourced insights with distinct illustrations,
four daily picks shared with Home, topic browsing, full reading views and
device-local bookmarks. PC and mobile support manual swipe, dots and keyboard.
Preference and allergen choices each have their own corresponding symbol.
All 267 tests pass, analysis is clean and the production web build passes.
The dot row is now compact (32 px). Source is prepared for the requested main
push; hosted verification and native releases remain separate.
[Insights feature and review](docs/planning/FRONTEND_V0_7_0_REVIEW.md).

Frontend **v0.6.3+10** replaces the desktop insight tile with fresh transparent
bowl-and-leaf artwork, keeping the whole illustration visible in both themes.
240 tests pass, analysis/build are clean, and manual mobile release defaults
match `0.6.3+10`. Hosted verification is pending; work stops after the requested push.
[Correction review and deployment status](docs/planning/FRONTEND_V0_6_3_REVIEW.md).

Frontend **v0.6.2+9** corrects Profile summaries to show only selected items:
first two chips, then `+N` for the rest. Empty groups show no chips. The complete
separate editors preserve every selection.
**237 tests pass**; analysis/build are clean and production is READY with
55 hosted checks. [Correction review and production proof](docs/planning/FRONTEND_V0_6_2_REVIEW.md).

**Published: frontend v0.6.2+9 and backend v0.12.0.** Automatic barcode/front/back
reading, post-capture highlights and the supplied Home/product result layouts are
deployed. The Enter package label form is removed. Both production deployments are
READY, with **55 frontend / 389 backend hosted checks** and all 21 OCR hashes.
[Frontend review](docs/planning/FRONTEND_V0_6_2_REVIEW.md) ·
[Backend review](docs/planning/BACKEND_V0_12_0_REVIEW.md).

**Frontend v0.6.1+8 correction:** sidebar decoration moves behind navigation, a
fresh wide insight banner replaces the close crop, and mobile recent scans is
compact. Profile has separate editors with eight food preferences, twelve allergen
reminders and selected counts/chips. The green mobile pill tracks hold or direct
drag and selects on release. Its **232 passing tests**, review and deployment
status are in [the correction review](docs/planning/FRONTEND_V0_6_1_REVIEW.md).

The preceding **backend v0.11.0** and **frontend v0.5.0+6** sources are pushed
with READY deployments and **389 backend / 49 frontend hosted checks**, including
all 21 OCR asset hashes. That historical read-only audit excludes subsequent versions
and authenticated AI generation. Backend v0.11.0 passed 1,303 tests with five provider/emulator
skips; that historical count does not certify subsequent v0.12.0 edits.
[AI configuration](docs/architecture/AI_ROUTING.md) ·
[Backend v0.11 review](docs/planning/BACKEND_V0_11_0_REVIEW.md) ·
[Hosted audit](docs/research/HOSTED_READONLY_AUDIT_2026_10_08.json).

**Backend v0.10.0** adds a read-only researched-product database with **243 dated
source observations**, including **174 manufacturer/retailer website records**.
Frontend **v0.5.0+6** searches these records and opens ingredient,
allergen-declaration, nutrition-basis and source details even when the barcode is
unknown. Its source is pushed and read-only hosted checks pass. Missing and conflicting facts
remain explicit. [Product list](docs/research/POPULAR_PRODUCTS_ADDED.md) ·
[Database plan](docs/planning/POPULAR_PRODUCTS_DATABASE_PLAN.md).

**Backend v0.9.0 Reviewed Ingredient Functions** expands the partial English/Hindi
glossary to six entries and hardens source/alias validation. **Frontend v0.4.0+5
Sourced Comparison and Ingredient Detail** connects exact source/table comparison
and bilingual evidence details to the existing screens. Android camera startup
no longer waits for interrupted-gallery recovery. Backend is pushed/READY with
26 hosted checks; frontend is independently pushed/READY with 49 hosted checks,
all 21 OCR hashes, 181 tests, clean analysis, release build and browser workflows.
[Current production proof](docs/research/FRONTEND_V0_4_0_PRODUCTION.json).

Historical frontend v0.3.0 remains published/hosted-verified with 49 checks.
Backend v0.8.0 was pushed and hosted-verified with 25 checks.
[Current implementation plan](docs/planning/FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md) ·
[Feature tracker](docs/planning/FEATURE_TRACKER.md).

- Photograph a barcode or search sourced identity/ingredient/claim text and choose
  the matching catalogue record. Known barcode reports do not need an AI request.
- Read dated historical reports, nutrition bases, source references and unknowns.
- Photograph an unknown package's front/back for an extraction-qualified result;
  optionally accept matching structured facts for a separate confirmed report.
- See approximate total-sugar cubes, seven reviewed numerical claim types and
  six reviewed English/Hindi ingredient functions where evidence permits.
- Continue as a guest with device-local saved reports/history, or optionally sign in
  to sync a private account display name, saved reports and history across devices.
- Use responsive botanical Welcome on mobile and PC, compact light/dark Home and
  the existing floating Home/Scan/Compare/Saved navigation, with Profile at the top right.
- Read private camera/gallery captures automatically through optional backend AI
  with transfer consent, or conservative local English/Hindi OCR. Unreadable facts
  request a clearer photo. Missing values and ambiguous tables remain unknown.
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

Continuous live-feed recognition/highlights and personal
suitability remain future work. v0.7.0 implements twenty sourced editorial
insights with unique artwork, daily selection, readers and local bookmarks. Profile
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
| Reviewed ingredient glossary | Six technological-function entries; partial coverage in English/Hindi |

Generic IFCT/INDB/USDA food composition does not fill a branded packet's unknown
values. Missing is unknown, not zero. Tables retain basis and preparation; source
conflicts are preserved. Sugar cubes use the explicit approximate 4 g/cube policy.
No custom model/training is selected. Optional Gemini/OpenAI extraction uses one
globally active server credential with sticky manual/failure replacement.

Local v0.12.0 retains the original SQLite data, extends the research index with
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
