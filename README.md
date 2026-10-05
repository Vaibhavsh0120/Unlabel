<div align="center">

# Unlabel

### Label Padhega India

**Understand the label. Know what is inside.**

![Version](https://img.shields.io/badge/version-0.0.0-59636e?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.47.4-59636e?style=flat-square)
![Stage](https://img.shields.io/badge/stage-foundation-59636e?style=flat-square)
![Targets](https://img.shields.io/badge/targets-Android%20%C2%B7%20iOS%20%C2%B7%20Web-59636e?style=flat-square)

[Architecture](docs/architecture/SYSTEM.md) · [Data workflow](docs/architecture/DATA_FLOW.md) · [Folder guide](docs/architecture/FOLDER_STRUCTURE.md) · [Teammate handoff](docs/planning/TEAM_HANDOFF.md)

</div>

---

Unlabel is a college mini-project that will turn packaged food labels into simple, evidence-backed explanations in English or Hindi. Scan the front and back, check marketing claims, understand ingredients, and see how a food fits your preferences.

## What is ready

**This is the v0.0.0 foundation, not a working food scanner.**

| Ready now | Planned next |
| --- | --- |
| One Flutter starter for Android, iOS and web | Camera capture, OCR and ingredient highlighting |
| Responsive starter with System / Light / Dark appearance | Reviewed glossary and bilingual explanations |
| Platform projects and tracked dependency lockfile | Versioned nutrition, claim and allergen rules |
| Manual APK + unsigned IPA release workflow | Optional FastAPI, Gemini and product enrichment |
| Architecture, sources, workflows and team boundaries | Online analysis, saved results and limited offline access |

The color theme is undecided. The starter uses temporary stock Material styles. Backend, knowledge corpus, trained models and Vercel deployment do not exist yet.

## Four connected features

| Feature | The experience | The evidence |
| --- | --- | --- |
| **Check the claim** | Compare “high protein”, “no added sugar” and other front-label claims against the back | Reviewed rules with input/source references; uncertainty when information is missing |
| **Ingredient X-ray** | Highlight useful ingredient/nutrient information in the camera view | Local OCR regions and bounding boxes; provisional until corrected |
| **Personal suitability** | See separate reasons for dietary and allergy preferences | Confirmed product facts matched to preferences stored locally |
| **Ingredient translator** | Tap a technical name for a simple English/Hindi explanation | Reviewed aliases, ingredient purpose and evidence-backed context |

Unknown chemicals are not automatically dangerous. “Allergen not detected” is not “allergen-free”. Missing evidence will remain uncertain. [Full feature workflows →](docs/planning/FEATURES.md)

## How everything connects

~~~mermaid
flowchart LR
  Barcode["Product barcode"] --> API["FastAPI · Vercel backend"]
  API --> OFF["Open Food Facts product data"]
  OFF --> Review["Review product facts"]
  Label["Package claims / missing fields"] --> OCR["Local OCR + correction"]
  OCR --> Review
  Review --> Rules["Backend: reviewed FSSAI criteria"]
  Rules -. "Optional wording" .-> AI["Gemini / eligible AI provider"]
  Rules --> Result["Findings + evidence"]
  AI --> Result
  Result --> Local["Local preferences + saved scans"]
  Knowledge["Reviewed canonical knowledge"] --> Rules
~~~

**Open Food Facts does the product-data heavy lifting:** barcode identity, ingredients, nutrition and available source-tagged computed insights. The backend applies reviewed FSSAI criteria to available evidence; no live FSSAI verification API or official certification is assumed. The confirmed physical package takes priority when its facts differ from the community record. Missing fields stay uncertain, and a record-only assessment is identified as such. [Open Food Facts integration plan →](docs/architecture/OPEN_FOOD_FACTS.md)

Structured rules and ingredient/alias lookup are enough initially. No vector RAG or custom model training is required. Gemini only explains established findings; it cannot change numbers, verdicts or sources. [Evidence strategy →](docs/research/EVIDENCE_STRATEGY.md) · [AI/training options →](docs/research/AI_TRAINING.md)

## Online-first, with a few offline features

New product lookup and rule analysis use the backend. Offline scope is limited to previously saved results/product snapshots, local preferences and an optional small bundled ingredient glossary. Saved findings retain their source, date and versions; they are not refreshed compliance checks.

No duplicate Dart rule engine is required for the MVP. On-device OCR may still capture a draft when supported, but fresh analysis waits for the backend. Website offline access needs an initial load and explicit app/saved-content caching; it is not implemented or automatic now. [Complete data flow →](docs/architecture/DATA_FLOW.md)

## One frontend, two future Vercel projects

| Part | Stack | Deployment |
| --- | --- | --- |
| Frontend | One Flutter app: Android, iPhone/iPad and web | Website Vercel project rooted at frontend; native apps call the same API |
| Backend | Python + FastAPI, selected for quicker development | Separate Vercel project rooted at backend |
| Product data | Open Food Facts, selected as primary online product-data provider | Read-only backend adapter; missing records permit package-data entry; backend outages defer new analysis |
| Knowledge | Reviewed JSON/CSV sources, aliases, rules and translations | Read-only client/server bundles; optional local SQLite index |

The backend will be stateless. A writable SQLite file cannot be treated as durable Vercel storage. Flutter web needs a pinned custom build/prebuilt path. [Deployment plan →](docs/architecture/DEPLOYMENT_PLAN.md)

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
├── backend/             Future FastAPI modules; not implemented
├── knowledge/           Canonical reviewed evidence and rules
├── contracts/           Shared API/schema/version boundaries
├── data/                Synthetic fixtures; private data ignored
├── design/              Shared token/asset folders; palette undecided
├── ai/                  Optional experiments; no training
├── scripts/             Reserved maintenance/export tools
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

There is no backend to run and no API key needed for this starter.

## Manual releases and version sync

Open [GitHub Actions](https://github.com/Vaibhavsh0120/Unlabel/actions), select **Manual APK and unsigned IPA release**, and choose **Run workflow**. Supply the product version, increasing build number and source reference. Leave the backend URL empty until deployment exists.

The workflow resolves one source commit, checks Flutter, builds both platforms with the same version/build, verifies uploaded artifacts, and attaches APK, unsigned IPA, checksums and a manifest to a release. Existing tags/assets are never overwritten.

**The IPA is unsigned and not directly installable.** APKs currently use demo debug signing; reliable installed-app upgrades need a stable release key. Private repositories have limited free runner allowances; this workflow uses standard runners and does not enable billing.

Backend/web deployment versions can differ while remaining compatible with installed apps. Stable API majors, contract capabilities and knowledge versions provide that compatibility. Deploy compatible backend changes before dependent clients. [Release/versioning details →](docs/planning/RELEASE_VERSIONING.md)

## For the team

[Handoff](docs/planning/TEAM_HANDOFF.md) → [System](docs/architecture/SYSTEM.md) → [API plan](docs/architecture/API_PLAN.md) → [Roadmap](docs/planning/ROADMAP.md).

UI targets include iPhone, iPad portrait/landscape and MacBook sizes in both modes, with touch/keyboard access and readable text. [UI requirements →](docs/planning/UI_REQUIREMENTS.md)

Research checked **5 October 2026**. Recheck provider terms and source applicability before use. The supplied compliance reference is background for a later extension, not official certification. Keep secrets/private scans out of Git. [Contribution boundaries →](CONTRIBUTING.md)
