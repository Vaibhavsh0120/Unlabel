# System architecture

Decision updated: **2026-10-05**. Frontend v0.0.0 remains the Flutter starter. Backend v0.2.1 implements FastAPI health/meta, separate live OFF product/nutrition lookup and confirmed-value normalization. Both Vercel projects automatically deploy main. Scanning and rule evaluation remain planned; see the release review for production evidence.

## Product and delivery boundary

Unlabel explains packaged food labels through claim checks, ingredient highlighting, local personal suitability and plain English/Hindi explanations. The college project must work within **₹0 additional platform cost, no credit card and no billing upgrade**.

One Flutter project lives directly in `frontend/`, targeting Android, iOS and web. Its generated `web/` directory is a platform directory. Two configured Vercel projects serve the Flutter static website and the shared FastAPI backend. Native apps call that same API. An existing laptop provides an optional private local demo backend.

The MVP is online-first. Open Food Facts supplies most product data and available source-tagged computed insights; the Python backend applies reviewed FSSAI/ingredient criteria. OCR captures package claims and fills missing or conflicting fields. No custom model training or second Dart rule engine is required. Optional generative AI rewrites established explanations. See [deployment](DEPLOYMENT_PLAN.md) and [training research](../research/AI_TRAINING.md).

## Component boundaries

~~~mermaid
flowchart LR
  subgraph Client["Flutter — Android / iOS / web"]
    OCR["Platform camera + OCR"] --> Review["Pair package sides + correct fields"]
    Barcode["Barcode lookup"] --> Review
    Results["Findings + evidence + templates"] --> Saved["Dated local saved reports"]
    Results --> Personal["Local preferences / suitability / history"]
  end
  subgraph Backend["FastAPI — stateless Vercel Function / local laptop"]
    API["Contract + capability validation"] --> Parse["Normalize source-tagged facts"]
    API --> OFF["Open Food Facts product lookup"]
    OFF --> Review
    Parse --> Rules["Reviewed FSSAI/ingredient rules"]
    Rules --> Explain["Templates / optional protected AI"]
    Evidence["Bundled read-only JSON knowledge"] --> Rules
  end
  Canonical["Canonical knowledge/ + contracts/"] --> Evidence
  Barcode --> API
  Review -->|"Confirmed public text + region IDs"| API
  Explain -->|"Versioned findings + neutral facts"| Results
  Explain -.->|"Public product facts only"| Gemini["Optional Gemini Free Tier"]
~~~

Knowledge packaging and these links are planned, not implemented. Backend rule fixtures and provider/client contract fixtures verify missing values, applicability, provenance and compatible reports.

| Boundary | Responsibility |
| --- | --- |
| Camera/OCR adapters | Platform permissions, frame lifecycle, image geometry and text-region IDs; no legal verdicts |
| Scan state/repository | Front/back pairing, correction revisions, local save/delete and stale-response rejection |
| `core/analysis` + knowledge loader | Report models/presentation, version/source status and optional small glossary; no fresh offline rule engine required |
| Backend parsing/analysis | Main reviewed rule evaluation with field provenance, applicable criteria and unknowns |
| Knowledge service | Exact ingredient aliases/INS identifiers, reviewed provisions and source metadata |
| Local suitability matcher | Select relevant neutral reasons using preferences kept on the device/browser |
| AI adapter | Optional wording only; immutable numbers, outcomes and allowed evidence IDs |
| Open Food Facts product adapter | Selected read-only barcode provider; source-tagged enrichment; confirmed physical label remains the scan source |

Use modest modules and one backend API. Microservices, vector databases, training infrastructure and a cloud user-profile database are unnecessary for the baseline.

Open Food Facts is the primary online product-data provider through `backend/app/providers/products/`. Basic product views can use its source-tagged record directly; checking the current package's marketing claims requires relevant claim/field confirmation. If OFF is unavailable but the backend is reachable, analyze available package fields; if the backend is unavailable, defer fresh analysis and offer saved results/draft capture. [Provider workflow](OPEN_FOOD_FACTS.md).

## Shared rules and evidence

`knowledge/` contains reviewed declarative criteria, aliases, source records and bilingual templates for the Python backend. An optional small ingredient glossary may be packaged as Flutter assets. Product facts come primarily from OFF; criteria come from reviewed FSSAI/other evidence. There is one backend rule evaluator in the MVP.

Unavailable rules, unreadable panels or unknown quantities return `insufficient_information`; absence is not safety/compliance proof. Fixtures verify rule IDs, applicability, units, outcomes and references. OFF-record assessments identify their input origin and cannot certify the current physical package or complete legal compliance. FSSAI supplies criteria, not a live verification service.

The paired, user-confirmed package is the product source. Preserve original/corrected field provenance, panel completeness and nutrient bases. Images and coordinates stay local. Regulatory activation requires source/provision review, effective dates and recorded reuse rights.

Ingredient retrieval starts with names, aliases and INS/E-number IDs. Approved evidence paragraphs ground explanations without requiring vector RAG. Retrieval relevance never decides numeric rule applicability.

## Operating modes

| Mode | Planned behavior |
| --- | --- |
| Backend reachable, Gemini disabled | OFF product data plus reviewed rule checks, evidence and English/Hindi templates |
| Backend reachable, protected AI available | Same findings; optional validated generated wording |
| Backend unreachable/offline | Saved dated results/snapshots and preferences; optional glossary/draft capture; fresh lookup/analysis waits |
| Internet absent, local backend reachable | Analyze available confirmed fields with packaged backend criteria/templates; no uncached OFF/cloud lookup |
| Website offline | Saved-content access only after initial load and explicit app/local-content caching is implemented and tested |
| Fixture demo | Synthetic/pre-reviewed examples visibly identified as demo data |

Native OCR requires bundled device models. Browser OCR needs its own supported adapter/assets; mobile ML Kit is not a web implementation. Flutter does not automatically provide a complete offline website. [Flutter web deployment](https://docs.flutter.dev/deployment/web), [web caching FAQ](https://docs.flutter.dev/platform-integration/web/faq).

## Runtime, compatibility and privacy

`GET /v1/meta` exposes contract/knowledge/rule versions and capabilities. Reports identify source origins, assessed criteria and versions. The client suppresses incompatible affected findings rather than merging conflicting results. Saved reports retain their original analysis/evidence dates; viewing them offline needs no handshake, but does not recompute or refresh rules.

Vercel uses bundled read-only JSON knowledge. Build access to root `knowledge/` does not include it automatically in the deployed function: a future staging step validates and packages required files and a version manifest. SQLite remains an optional rebuildable local-laptop index. `/tmp`, instance caches and counters are disposable; none supplies durable hosted storage or global quota protection. [FastAPI support](https://vercel.com/docs/frameworks/backend/fastapi), [Python runtime](https://vercel.com/docs/functions/runtimes/python).

Client `BACKEND_BASE_URL` is public configuration, never a credential. Gemini keys stay in backend environment settings. `AI_PROVIDER=disabled` and an empty model are the baseline. Public AI stays disabled until verified individual access for an eligible adult beta and bounded requests exist. CORS and an embedded shared app token cannot provide authentication.

Preferences, personal suitability and scan history stay in the phone/browser. Only public barcodes, necessary public label fields and generic product evidence go to the API/provider. Hosted services need HTTPS, minimal redacted logs and the choices recorded in [SAFETY_PRIVACY.md](../SAFETY_PRIVACY.md).

The starter/workflow does not prove OCR quality, saved-content caching, legal criteria, live providers, hosted behavior or dietary suitability. Validate those during implementation.

Backend v0.2.1 also provides a separate optional export-origin identity catalogue: official TSV stream -> India JSONL projection -> atomic read-only SQLite index. It does not replace the current live OFF product/nutrition routes. The verified local index is ignored; hosted artifact distribution remains a v0.2.2 gate. Source dates/unknowns stay visible and manual replacement is every nine months. [Implemented catalogue workflow](CATALOGUE.md).
