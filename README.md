<div align="center">

# Unlabel

<picture>
  <source media="(max-width: 600px)" srcset="docs/assets/readme/hero-mobile.svg">
  <img src="docs/assets/readme/hero.svg" width="1200" alt="Read the label. Know what's inside. An illustrated food packet and leaf in Unlabel's forest-green and mint colors.">
</picture>

<p>
  <a href="https://unlabel-india.vercel.app"><img src="docs/assets/readme/live-preview.svg" width="156" height="48" alt="Open Unlabel live preview"></a>
  <a href="https://github.com/Vaibhavsh0120/Unlabel/releases?q=demo+APK&amp;expanded=true"><img src="docs/assets/readme/download-apps.svg" width="156" height="48" alt="Download Android and iOS apps"></a>
  <a href="https://unlabel-api.vercel.app/docs"><img src="docs/assets/readme/backend-api.svg" width="156" height="48" alt="Open the deployed Vercel backend API documentation"></a>
  <a href="docs/README.md"><img src="docs/assets/readme/documentation.svg" width="156" height="48" alt="Read the documentation"></a>
</p>

[![Build and tests status](https://img.shields.io/github/actions/workflow/status/Vaibhavsh0120/Unlabel/maintenance-ci.yml?branch=main&label=Build%20%26%20tests)](https://github.com/Vaibhavsh0120/Unlabel/actions/workflows/maintenance-ci.yml) [![Frontend version](https://img.shields.io/badge/frontend-0.11.0%2B15-155b4b)](frontend/pubspec.yaml) [![Backend version](https://img.shields.io/badge/backend-0.15.0-155b4b)](backend/pyproject.toml)

</div>

## Use Unlabel

| Platform | Get started |
| --- | --- |
| **Web** | [Open Unlabel](https://unlabel-india.vercel.app) in your browser. |
| **Android** | Download the demo APK from the newest [Android / iOS release](https://github.com/Vaibhavsh0120/Unlabel/releases?q=demo+APK&expanded=true). |
| **iPhone / iPad** | Add the source below in **LiveContainer → Sources → +**. LiveContainer must already be installed and configured. |
| **Developers** | [API documentation](https://unlabel-api.vercel.app/docs) · [API metadata](https://unlabel-api.vercel.app/v1/meta) |

**LiveContainer source — copy this URL:**

[https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json](https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json)

[Open the source](https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json) · [Download the unsigned IPA](https://github.com/Vaibhavsh0120/Unlabel/releases?q=demo+APK&expanded=true)

The source and IPA downloads are verified. If you added the source while it
returned HTTP 404, refresh it; remove and add it again if the old error persists.
Import and launch on an actual iPhone remain unverified.

## What you can do

| | |
| --- | --- |
| **Read a label**<br>Capture or choose package photos, with on-device text reading and optional AI extraction after consent. | **Explore the evidence**<br>Find products, read nutrition and ingredient explanations, and see original sources and dates. |
| **Compare products**<br>View compatible nutrition tables side by side, with missing facts and conflicting sources kept visible. | **Keep what matters**<br>Save reports locally, set device-only food preferences and allergen reminders, or choose optional account sync. |
| **Learn a little daily**<br>Discover four daily picks from 20 sourced Insights, browse topics and bookmark articles on your device. | **Understand the limits**<br>Reviewed label-claim checks explain their inputs. Missing information stays unknown; no invented health score. |

### Latest update

Barcode scanning now uses the free `mobile_scanner` package: native platform
decoders and a bundled ZXing-C++ WebAssembly reader for web. The scanner follows
the mobile reference, with front/back photo capture, gallery and lifecycle guards.
Product information follows the supplied desktop/mobile hierarchy, with smaller
phone text, nutrition basis, unknown/conflicting facts and source references.
Guests selecting Sign-in methods receive a sign-in toast.

Every backend source can be switched off. Keyed sources automatically stay off
without credentials; a fresh clone can use the bundled data without vendor accounts.
[Optional-source setup](docs/architecture/OPTIONAL_SOURCES.md).
NutriGraph is configured server-side and remains temporary; its supplied endpoint
returned HTML 404 during testing, so successful live lookup is unverified.
[Frontend scope and checks](docs/planning/FRONTEND_V0_11_0_REVIEW.md) ·
[Backend scope and checks](docs/planning/BACKEND_V0_15_0_REVIEW.md).

Publication, hosted checks and native/device evidence are recorded separately in
[the release ledger](docs/planning/CONTROLLED_RELEASES.md).

## Run locally

Install **Git and Python 3.12+**, then clone the project:

```sh
git clone https://github.com/Vaibhavsh0120/Unlabel.git
cd Unlabel
```

**Windows / PowerShell**

```powershell
./scripts/setup.ps1
./scripts/run-local.ps1
```

**macOS / Linux**

```sh
python3 scripts/setup.py
python3 scripts/run_local.py
```

Setup restores dependencies, pinned Flutter tooling and verified product data.
Choose a key file, hidden key paste or safe example settings when prompted.
Never commit plaintext `.env` files or credentials.

Run `python scripts/run_local.py` for Local, Production API, or HTTPS Local network.
Caddy and certificate instructions: [local network tools](scripts/tools/README.md).

| Local service | Address |
| --- | --- |
| Web app | http://127.0.0.1:7357 |
| API documentation | http://127.0.0.1:8000/docs |

Use `--scope frontend` or `--scope backend` with the Python setup/runner to work
on one component. The runner supplies local API, catalogue and CORS settings.
[Full setup and troubleshooting](docs/planning/LOCAL_DEVELOPMENT.md).

## How it works

**Flutter app → FastAPI → sourced catalogue and reviewed knowledge**

The catalogue contains **24,641 supported barcodes** from the preserved
India-tagged Open Food Facts snapshot. A separate research index holds
**243 sourced observations** and **120 image descriptors**. Retail and regional
coverage has not been measured; decorative artwork is never product evidence.

Facts retain their source, date and nutrition-table basis. Compatible package
observations can fill confirmed gaps; conflicting sources remain separate.
Generic food-composition tables never fill a branded packet's unknown values.
[Data flow](docs/architecture/DATA_FLOW.md) · [Product discovery](docs/architecture/PRODUCT_DISCOVERY.md) · [Report rules](docs/architecture/LABEL_REPORT.md).

<details>
<summary><strong>Privacy, offline access and data boundaries</strong></summary>

- Photos and raw text remain private; optional server extraction requires consent.
  AI output stays unverified until accepted, with bounded private staging separate
  from public catalogue admission.
- Guests retain useful local workflows. Google or email/password sign-in selects
  a separate account namespace; linking both keeps the same library. Account/device
  differences require an explicit choice. Optional profile thumbnails and gender
  settings stay private in the existing Firebase database.
  [Account and profile details](docs/architecture/ACCOUNT_PROFILE.md).
- Appearance, Welcome completion, dietary reminders and article bookmarks stay
  on the device. Shared preferences are convenience storage, not an encrypted backup.
- Previously loaded, dated reports remain readable locally. New lookups and
  analysis need the backend; offline website first-load is not promised.
- Firebase uses the free tier with no linked billing. No paid Storage/Functions
  or card is required. Optional external AI providers have their own availability
  and account requirements.
- Reviewed FSSAI checks cover seven scoped numerical claims; the English/Hindi
  ingredient glossary covers six technological functions. These do not establish
  allergy safety, general health suitability or complete regulatory compliance.

[Privacy and evidence](docs/SAFETY_PRIVACY.md) · [Community catalogue](docs/architecture/COMMUNITY_CATALOGUE.md) · [AI routing](docs/architecture/AI_ROUTING.md).

</details>

## Project guide

| Find your way | Start here |
| --- | --- |
| **Understand the project** | [Documentation index](docs/README.md) · [Feature tracker](docs/planning/FEATURE_TRACKER.md) · [Architecture](docs/architecture/SYSTEM.md) |
| **Develop and contribute** | [Contributing](CONTRIBUTING.md) · [Teammate handoff](docs/planning/TEAM_HANDOFF.md) · [Scripts](scripts/README.md) · [UI contract](DESIGN.md) |
| **Build and publish** | [Release/versioning](docs/planning/RELEASE_VERSIONING.md) · [Source release ledger](docs/planning/CONTROLLED_RELEASES.md) · [Vercel setup](docs/planning/VERCEL_SETUP.md) |
| **Check the evidence** | [Maintenance receipt](docs/research/MAINTENANCE_2026_10_12.json) · [Frontend review](docs/planning/FRONTEND_V0_9_0_REVIEW.md) · [Backend review](docs/planning/BACKEND_V0_13_0_REVIEW.md) |

<details>
<summary><strong>Repository map</strong></summary>

| Folder | Responsibility |
| --- | --- |
| [frontend](frontend/README.md) | Flutter app, native/web platforms, API client and local persistence |
| [backend](backend/README.md) | FastAPI, catalogue, reviewed checks and reports |
| [contracts](contracts/README.md) | Versioned schemas, historical OpenAPI and synthetic fixtures |
| [data](data/README.md) / [knowledge](knowledge/README.md) | Licensed source bundles, provenance and reviewed rules |
| [scripts](scripts/README.md) | Restore, run, encryption, imports and verified publication |
| [docs](docs/README.md) / design | Architecture, release evidence and supplied UI references |

</details>

Versions live in [frontend/pubspec.yaml](frontend/pubspec.yaml) and
[backend/pyproject.toml](backend/pyproject.toml). Runtime/build metadata derives
from those files. Web and API deploy independently from `main`; native artifacts
use a separate verified release. Historical release identities stay preserved.
