<div align="center">

# Unlabel

### Label Padhega India

**Understand the label. Know what is inside.**

![Frontend](https://img.shields.io/badge/frontend-0.0.0-59636e?style=flat-square)
![Backend](https://img.shields.io/badge/backend-0.4.0-59636e?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.47.4-59636e?style=flat-square)
![Stage](https://img.shields.io/badge/stage-backend%20core-59636e?style=flat-square)
![Targets](https://img.shields.io/badge/targets-Android%20%C2%B7%20iOS%20%C2%B7%20Web-59636e?style=flat-square)

[Architecture](docs/architecture/SYSTEM.md) · [Data workflow](docs/architecture/DATA_FLOW.md) · [Folder guide](docs/architecture/FOLDER_STRUCTURE.md) · [Teammate handoff](docs/planning/TEAM_HANDOFF.md)

[Website](https://unlabel-india.vercel.app) · [Backend API](https://unlabel-api.vercel.app/v1/meta) · [Catalogue status](https://unlabel-api.vercel.app/v1/catalogue) · [API docs](https://unlabel-api.vercel.app/docs)

</div>

---

Unlabel is a college mini-project that will turn packaged food labels into simple, evidence-backed explanations in English or Hindi. Scan the front and back, check marketing claims, understand ingredients, and see how a food fits your preferences.

## Clone and run

Install Git and Python 3.12+, then run from the project folder:

~~~powershell
./scripts/setup.ps1
./scripts/run-local.ps1
~~~

Setup restores settings, dependencies and product data. Choose a key file, hidden key paste or safe defaults.

| Local service | Open |
| --- | --- |
| Website | http://127.0.0.1:7357 |
| API docs | http://127.0.0.1:8000/docs |

[Platform options and encryption guide →](docs/planning/LOCAL_DEVELOPMENT.md)

## What is ready

**Production backend v0.4.0 is published; local v0.5.0 Useful Label Report passes focused API/contracts. Frontend remains 0.0.0+1.** Live barcode lookup, direct nutrition, normalization, the rich India snapshot and seven numerical FSSAI claim checks are preserved. Four APIs save/deduplicate structured package observations automatically, stage unverified candidates and resolve compatible sourced fields. Firebase Unlabel is configured on its free tier with no billing. Local v0.5.0 adds current-label and historical barcode reports, a partial three-entry reviewed ingredient glossary and a declared 4 g/cube sugar approximation. Full review, push and hosted checks are pending; camera/OCR and background saving still need frontend integration. [Published v0.4.0 proof](docs/research/BACKEND_V0_4_0_PRODUCTION.json) · [v0.5.0 report scope](docs/architecture/LABEL_REPORT.md) · [Master plan](docs/planning/MASTER_PLAN.md).

| Ready now | Planned next |
| --- | --- |
| One Flutter starter for Android, iOS and web | Camera capture, OCR and ingredient highlighting |
| FastAPI health/meta, OFF product/nutrition lookup and confirmed normalization | Full analysis report, health-score policy and comparison |
| Rich facts: 24,641 validated barcodes, verified 59.58 MiB SQLite | Camera integration with explicit live/snapshot selection |
| Seven reviewed confirmed-label numerical claims, rules and evidence metadata | Broader claim coverage, ingredients and bilingual explanations |
| Catalogue status, source age and nine-month refresh date | Saved results, history and local preferences |
| Public lookup and confirmed checks need no interactive account; automatic observation APIs and sourced resolution are implemented | Camera/correction integration with anonymous background saving |
| Confirmed nutrient rows normalized with original values and provenance | OCR-to-API integration and nutrition visualizations |
| Responsive starter with System / Light / Dark appearance | Reviewed glossary and bilingual explanations |
| Platform projects and tracked dependency lockfile | Reviewed nutrition classifications and allergen policies |
| Manual APK + unsigned IPA release workflow | Optional Gemini explanations |
| Architecture, sources, workflows and team boundaries | Online analysis, saved results and limited offline access |

The color theme is undecided. The starter uses temporary stock Material styles. Both Vercel projects are configured for automatic Git deployments. The website renders the starter; [v0.3.0 verification](docs/planning/BACKEND_V0_3_0_REVIEW.md) records the published API. Glossary and wider rules remain future work. No custom model or training is selected. [Hosting settings and URLs →](docs/planning/VERCEL_SETUP.md)

[Master architecture plan](docs/planning/MASTER_PLAN.md) · [Feature tracker](docs/planning/FEATURE_TRACKER.md) · [API/run guide](backend/README.md) · [Community catalogue](docs/architecture/COMMUNITY_CATALOGUE.md)

## Four connected features

| Feature | The experience | The evidence |
| --- | --- | --- |
| **Check the claim** | Compare “high protein”, “no added sugar” and other front-label claims against the back | Reviewed rules with input/source references; uncertainty when information is missing |
| **Ingredient X-ray** | Highlight useful ingredient/nutrient information in the camera view | Local OCR regions and bounding boxes; provisional until corrected |
| **Personal suitability** | See separate reasons for dietary and allergy preferences | Confirmed product facts matched to preferences stored locally |
| **Ingredient translator** | Tap a technical name for a simple English/Hindi explanation | Reviewed aliases, ingredient purpose and evidence-backed context |

Unknown chemicals are not automatically dangerous. “Allergen not detected” is not “allergen-free”. Missing evidence will remain uncertain. [Full feature workflows →](docs/planning/FEATURES.md)

## How everything connects

This is the complete target flow. The backend implements structured observation
persistence and source resolution; OCR, reports and client integration remain
pending. The client will save corrected confirmed public facts automatically,
with extracted candidates staged as unverified and anonymous authentication
behind the scenes. There is no separate Share action.

~~~mermaid
flowchart LR
  Barcode["Product barcode"] --> API["FastAPI · Vercel backend"]
  API --> Snapshot["Bundled India catalogue: identity + rich facts"]
  Snapshot --> Review["Review product facts"]
  API --> OFF["Live Open Food Facts: product / nutrition"]
  OFF --> Review["Review product facts"]
  Label["Package claims / missing fields"] --> OCR["Local OCR + correction"]
  OCR --> Review
  Review --> Rules["Backend: reviewed FSSAI criteria"]
  OCR -->|"Structured candidates only"| Staging["Staged / unverified facts"]
  Review -->|"Automatic confirmed-fact save + dedup"| Community["Firebase Unlabel: product observations"]
  Community -->|"Validated compatible gap fills; qualified origin"| Resolved["Compatible fields + per-field source/date"]
  Community -->|"Known conflict / identity mismatch"| Moderation["Operator exact-hash review"]
  Moderation --> Resolved["Compatible fields + per-field source/date"]
  Resolved --> Review
  Rules -. "Optional wording" .-> AI["Gemini / eligible AI provider"]
  Rules --> Result["Findings + evidence"]
  AI --> Result
  Result --> Local["Local preferences + saved scans"]
  Knowledge["Reviewed canonical knowledge"] --> Rules
~~~

**Open Food Facts does the product-data heavy lifting:** barcode identity, ingredients, nutrition and available source-tagged computed insights. The separate catalogue route reads the bundled India snapshot without an OFF request. The separate facts route returns selected direct nutrition, availability-aware tags, record dates and a validated official image reference; live product/nutrition routes still query OFF. Legacy aggregate nutrition is unavailable as direct label evidence. Coverage is unverified and a missing snapshot record stays a dated 404. Nutrition tables retain their source, basis and preparation; separate tables are never silently combined. Confirmed physical-package values remain distinct from community data. Reviewed FSSAI numerical criteria run through a separate confirmed-label API; no live FSSAI verification API or official certification is assumed. [Open Food Facts integration →](docs/architecture/OPEN_FOOD_FACTS.md)

Normalization preserves zero, marks missing values as unknown, and converts compatible values to per 100 g or per 100 mL. It keeps an unmeasured serving as a serving, without guessing density or portion size. It does not infer added sugar from total sugar or salt from sodium. [Current API and examples →](backend/README.md)

Use local OCR and reviewed deterministic rules first. No custom model, training or vector database is selected. Gemini stays disabled; a benchmark may later justify an optional bounded extraction/wording fallback. Any candidate still requires correction and validation, and cannot change confirmed numbers, verdicts or sources. [Architecture/AI selection →](docs/planning/MASTER_PLAN.md) · [Evidence strategy →](docs/research/EVIDENCE_STRATEGY.md)

## Online-first, with a few offline features

New product lookup and rule analysis use the backend. Offline scope is limited to previously saved results/product snapshots, local preferences and an optional small bundled ingredient glossary. Saved findings retain their source, date and versions; they are not refreshed compliance checks.

No duplicate Dart rule engine is required for the MVP. On-device OCR may still capture a draft when supported, but fresh analysis waits for the backend. Website offline access needs an initial load and explicit app/saved-content caching; it is not implemented or automatic now. [Complete data flow →](docs/architecture/DATA_FLOW.md)

## One frontend, two Vercel projects

| Part | Stack | Deployment |
| --- | --- | --- |
| Frontend | One Flutter app: Android, iPhone/iPad and web | [unlabel-india.vercel.app](https://unlabel-india.vercel.app), rooted at frontend |
| Backend | Python + FastAPI, selected for quicker development | [unlabel-api.vercel.app](https://unlabel-api.vercel.app), rooted at backend; native apps use this same API |
| Product data | Open Food Facts live APIs + compact India snapshot | Separate live and read-only snapshot routes; source gaps remain visible |
| Product enrichment | Firebase Unlabel; first Standard database `unlabel`, Mumbai | Automatic observation APIs, qualified candidates and source resolution; free tier/no linked billing |
| Knowledge | Reviewed JSON/CSV sources, aliases, rules and translations | Read-only client/server bundles; optional local SQLite index |

The backend has no durable local state and generates verified read-only OFF SQLite/claim bundles. v0.4.0 uses Firestore for structured public observations and private staged candidates. Compatible fields retain individual source/date references, originals and conflicts. Photos/raw OCR/preferences/history stay private. Unlabel's first Standard database `unlabel` in Mumbai has its free tier enabled and no linked billing; no paid fallback is allowed. The website uses pinned Flutter 3.47.4. Pushes deploy both Vercel projects; mobile releases remain manual. v0.4.0 passed sixteen hosted HTTP checks with matching OFF/claim receipts. [Deployment configuration →](docs/planning/VERCEL_SETUP.md) · [Storage boundaries →](docs/architecture/COMMUNITY_CATALOGUE.md)

**₹0 and no credit card remain the baseline.** Stay within eligible free tiers, keep billing disabled, and preserve local/template fallbacks. Hosted AI and unlimited private CI are not guarantees. [Free-stack research →](docs/research/FREE_STACK.md)

## Repository guide

~~~text
Unlabel/
├── frontend/            One Flutter project directly here
│   ├── lib/             App, platform adapters and feature folders
│   ├── android/ ios/    Native platforms
│   ├── web/             Flutter website platform files
│   ├── assets/          Future glossary, translations and visuals
│   └── test/            Starter layout/theme checks
├── backend/             FastAPI local v0.5.0; production v0.4.0 released
├── knowledge/           Canonical reviewed evidence and rules
├── contracts/           Shared API/schema/version boundaries
├── data/                Reusable India source, provenance/licenses and fixtures
├── design/              Concept references and future tokens; palette undecided
├── ai/                  Optional experiments; no training
├── scripts/             Setup, local run, encryption and catalogue maintenance
├── docs/                Architecture, research and teammate handoff
└── .github/workflows/   Manual APK + unsigned IPA release
~~~

The root coordinates the product; it is not another app. [Every folder explained →](docs/architecture/FOLDER_STRUCTURE.md)

## Run the starter

Use **Flutter 3.47.4**:

~~~sh
cd frontend
flutter pub get
flutter run
~~~

~~~sh
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
~~~

No API key is needed for the starter or backend OFF reads. Gemini remains disabled.

## Manual releases and version sync

Open [GitHub Actions](https://github.com/Vaibhavsh0120/Unlabel/actions), select **Manual APK and unsigned IPA release**, and choose **Run workflow**. Supply the frontend version, increasing build number and source reference. For future API-enabled app builds, use `https://unlabel-api.vercel.app` as the backend URL. Existing v0.0.0 assets are unchanged.

The workflow resolves one source commit, checks Flutter, builds both platforms with the same version/build, verifies uploaded artifacts, and attaches APK, unsigned IPA, checksums and a manifest to a release. Existing tags/assets are never overwritten.

**The IPA is unsigned and not directly installable.** APKs currently use demo debug signing; reliable installed-app upgrades need a stable release key. Private repositories have limited free runner allowances; this workflow uses standard runners and does not enable billing.

Backend/web deployment versions can differ while remaining compatible with installed apps. Stable API majors, contract capabilities and knowledge versions provide that compatibility. Deploy compatible backend changes before dependent clients. [Release/versioning details →](docs/planning/RELEASE_VERSIONING.md)

## For the team

[Handoff](docs/planning/TEAM_HANDOFF.md) → [System](docs/architecture/SYSTEM.md) → [API plan](docs/architecture/API_PLAN.md) → [Roadmap](docs/planning/ROADMAP.md).

UI targets include iPhone, iPad portrait/landscape and MacBook sizes in both modes, with touch/keyboard access and readable text. [UI requirements →](docs/planning/UI_REQUIREMENTS.md)

Source and Firebase research checked **5–7 October 2026**. Recheck provider terms and source applicability before use. The supplied compliance reference is background for a later extension, not official certification. Keep plaintext secrets/private scans out of Git. [Contribution boundaries →](CONTRIBUTING.md)

Claim results retain selected table/context, row/region IDs, rule/source IDs and knowledge version. Statutory fibre energy alternatives use original rows and 4.2 kJ/kcal; normalization-v1 remains 4.184. Unknown alternatives or conflicts stay insufficient. High/source protein, no added sugar and multigrain are recognized but unreviewed. Numerical support does not certify health, allergy safety or complete compliance. [Claim API and synthetic examples](backend/README.md#reviewed-confirmed-label-claim-checks).
