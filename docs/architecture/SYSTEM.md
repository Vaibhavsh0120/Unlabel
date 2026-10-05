# System architecture

Decision updated: **2026-10-05**. Python/FastAPI is selected for quicker implementation. The Flutter Material starter and manual native-artifact workflow exist; scanning, rule evaluation, API services and deployment remain planned.

## Product and delivery boundary

Unlabel explains packaged food labels through claim checks, ingredient highlighting, local personal suitability and plain English/Hindi explanations. The college project must work within **₹0 additional platform cost, no credit card and no billing upgrade**.

One Flutter project lives directly in `frontend/`, targeting Android, iOS and web. Its generated `web/` directory is a platform directory. Later, two separate Vercel projects serve the Flutter static website and the shared FastAPI backend. Native apps call that same API. An existing laptop provides an optional private local demo backend.

No custom model training is required for the baseline: pretrained OCR extracts text, reviewed rules evaluate evidence, and optional generative AI rewrites the resulting explanations. See [deployment](DEPLOYMENT_PLAN.md) and [training research](../research/AI_TRAINING.md) for eligibility and limits.

## Component boundaries

~~~mermaid
flowchart LR
  subgraph Client["Flutter — Android / iOS / web"]
    OCR["Platform camera + OCR"] --> Review["Pair package sides + correct fields"]
    Review --> Offline["Reviewed offline rule subset"]
    Offline --> Results["Findings + evidence + templates"]
    Results --> Personal["Local preferences / suitability / history"]
  end
  subgraph Backend["FastAPI — stateless Vercel Function / local laptop"]
    API["Contract + capability validation"] --> Parse["Normalize confirmed fields"]
    Parse --> Rules["Expanded reviewed rule evaluator"]
    Rules --> Explain["Templates / optional protected AI"]
    Evidence["Bundled read-only JSON knowledge"] --> Rules
  end
  Canonical["Canonical knowledge/ + contracts/"] --> Offline
  Canonical --> Evidence
  Review -->|"Confirmed public text + region IDs"| API
  Explain -->|"Versioned findings + neutral facts"| Results
  Explain -.->|"Public product facts only"| Gemini["Optional Gemini Free Tier"]
~~~

Knowledge packaging and the links above are planned, not implemented. Shared parity fixtures must verify that supported Dart and Python evaluations agree.

| Boundary | Responsibility |
| --- | --- |
| Camera/OCR adapters | Platform permissions, frame lifecycle, image geometry and text-region IDs; no legal verdicts |
| Scan state/repository | Front/back pairing, correction revisions, local save/delete and stale-response rejection |
| `core/analysis` + knowledge loader | Supported reviewed offline evaluations, version checks and explicit unsupported/unknown findings |
| Backend parsing/analysis | Expanded normalized rule evaluation with field provenance and unknowns |
| Knowledge service | Exact ingredient aliases/INS identifiers, reviewed provisions and source metadata |
| Local suitability matcher | Select relevant neutral reasons using preferences kept on the device/browser |
| AI adapter | Optional wording only; immutable numbers, outcomes and allowed evidence IDs |
| Optional product adapter | Source-tagged enrichment; confirmed physical label remains the scan source |

Use modest modules and one backend API. Microservices, vector databases, training infrastructure and a cloud user-profile database are unnecessary for the baseline.

## Shared rules and evidence

`knowledge/` contains canonical declarative criteria, aliases, glossary entries, source records and bilingual templates. A reviewed common subset is packaged as Flutter assets; Python can evaluate additional reviewed rules online. There are two execution environments, **one source of thresholds and evidence definitions**.

The offline scope is explicit and versioned. A rule outside that scope, an unreadable panel or an unknown quantity returns `insufficient_information`; absence is not safety or compliance proof. Test fixtures under `contracts/` verify rule IDs, applicability, units, outcomes and references across evaluators.

The paired, user-confirmed package is the product source. Preserve original/corrected field provenance, panel completeness and nutrient bases. Images and coordinates stay local. Regulatory activation requires source/provision review, effective dates and recorded reuse rights.

Ingredient retrieval starts with names, aliases and INS/E-number IDs. Approved evidence paragraphs ground explanations without requiring vector RAG. Retrieval relevance never decides numeric rule applicability.

## Operating modes

| Mode | Planned behavior |
| --- | --- |
| Backend reachable, Gemini disabled | Expanded reviewed analysis, evidence and English/Hindi templates |
| Backend reachable, protected AI available | Same findings; optional validated generated wording |
| Backend unreachable or provider-free offline use | New supported offline findings, local glossary/templates, raw values and saved scans; expanded checks remain unknown/pending |
| Internet absent, local backend reachable | Expanded checks using packaged local evidence; no cloud enrichment |
| Website offline | Available only after initial load and explicit caching of app/OCR/knowledge assets is implemented and tested |
| Fixture demo | Synthetic/pre-reviewed examples visibly identified as demo data |

Native OCR requires bundled device models. Browser OCR needs its own supported adapter/assets; mobile ML Kit is not a web implementation. Flutter does not automatically provide a complete offline website. [Flutter web deployment](https://docs.flutter.dev/deployment/web), [web caching FAQ](https://docs.flutter.dev/platform-integration/web/faq).

## Runtime, compatibility and privacy

`GET /v1/meta` exposes contract/knowledge/rule versions and supported capabilities. Online responses identify evaluator scope and versions; local reports retain their own bundle versions. The client suppresses incompatible affected findings rather than merging conflicting results. An offline session must not require a network handshake to run its supported subset.

Vercel uses bundled read-only JSON knowledge. Build access to root `knowledge/` does not include it automatically in the deployed function: a future staging step validates and packages required files and a version manifest. SQLite remains an optional rebuildable local-laptop index. `/tmp`, instance caches and counters are disposable; none supplies durable hosted storage or global quota protection. [FastAPI support](https://vercel.com/docs/frameworks/backend/fastapi), [Python runtime](https://vercel.com/docs/functions/runtimes/python).

Client `BACKEND_BASE_URL` is public configuration, never a credential. Gemini keys stay in backend environment settings. `AI_PROVIDER=disabled` and an empty model are the baseline. Public AI stays disabled until verified individual access for an eligible adult beta and bounded requests exist. CORS and an embedded shared app token cannot provide authentication.

Preferences, personal suitability and scan history stay in the phone/browser. Only confirmed public label fields and generic product evidence may go to the optional API/provider. Hosted services need HTTPS, minimal redacted logs and the privacy choices recorded in [SAFETY_PRIVACY.md](../SAFETY_PRIVACY.md).

The present starter/workflow does not prove OCR quality, offline parity, legal criteria, live providers, hosted behavior or dietary suitability. Validate those during the corresponding implementation phase.
