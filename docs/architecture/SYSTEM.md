# System architecture

Updated **8 October 2026**. Frontend v0.3.0+4 is independently published
and hosted-verified; backend v0.8.0 is pushed and hosted-verified at exact
implementation `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` with 25 checks.
Its source-release publication is not established by that receipt.
Current work is backend v0.9.0 Reviewed Ingredient Functions and frontend
v0.4.0+5 Sourced Comparison and Ingredient Detail. Independent review, tests,
push and hosted evidence are recorded in the current component reviews.
Guests keep personal records local; optional password accounts use private
UID-specific sync, separately from public package facts. Capture/local OCR
are implemented; physical-device accuracy, live barcode decoding, highlights,
notifications and personal suitability remain separate future gates.

Current backend exports 21 paths / 22 operations and 29 validated synthetic
examples. Comparison uses the read-only `/v1/reports/compare` route; glossary
v0.9.0 adds six sourced functions. Private sync remains password-owned and
separate. [Master plan](../planning/MASTER_PLAN.md).

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
  subgraph Backend["FastAPI — disposable Vercel instances / local laptop"]
    API["Contract + capability validation"] --> Parse["Normalize source-tagged facts"]
    API --> OFF["Open Food Facts product lookup"]
    OFF --> Review
    Parse --> Rules["Reviewed FSSAI/ingredient rules"]
    Rules --> Explain["Templates / optional protected AI"]
    Evidence["Bundled read-only JSON knowledge"] --> Rules
    API --> Community["Automatic public observations / private staging"]
    Community --> Shared["Firestore Unlabel: qualified observations / review state"]
    Shared --> Resolve["Compatible fields + per-field sources / conflicts"]
    Resolve --> Review
  end
  Canonical["Canonical knowledge/ + contracts/"] --> Evidence
  Barcode --> API
  Review -->|"Confirmed public text + region IDs"| API
  Explain -->|"Versioned findings + neutral facts"| Results
  Explain -.->|"Public product facts only"| Gemini["Optional Gemini Free Tier"]
~~~

The diagram includes implemented and planned boundaries. The two-file reviewed
claim knowledge package, confirmed-label claim API, useful reports and three-entry
ingredient glossary are released. Manual frontend paths and local camera/gallery
capture are implemented; OCR, broader ingredient coverage, local suitability and
optional AI remain planned. Released private account sync is separate from the
public analysis pipeline shown here. Backend rule fixtures and provider/client
contract fixtures verify missing values, applicability, provenance and compatible
reports.

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
| Product enrichment | Implemented automatic save/dedup, private staging, qualified compatible submitter-confirmed candidates and conflict review |
| Resolved view | Complement compatible known fields with source/date references; preserve original observations/conflicts and never impute generic packet values |
| Private account sync | Optional password-owned display name/saved/history snapshots, revision conflicts and explicit client choices; separate from public observations |

Use modest modules and one backend API. Microservices, vector databases and
training infrastructure are unnecessary for the baseline. Optional private account
snapshots use the existing free Firestore database and separate ownership/storage
boundaries from public package observations.

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

The reviewed claim subset uses bundled read-only JSON. Build access to root `knowledge/` alone does not establish runtime inclusion: the implemented build validates exactly the claim-rule JSON and three-source registry, then packages them with a hash/length receipt under ignored `backend/app/claims/data/`. Hosted startup requires receipt verification even for an explicit override; invalid knowledge disables only claim/rule/evidence APIs. Metadata exposes the verified `knowledge_artifact` or null for direct canonical local loading. The current catalogue build validates the tracked OFF gzip and generates ignored SQLite plus a receipt under `backend/app/catalogue/data/`; hosted startup verifies that immutable artifact before enabling catalogue reads. `/tmp`, instance caches and counters are disposable; none supplies durable hosted storage or global quota protection. [FastAPI support](https://vercel.com/docs/frameworks/backend/fastapi), [Python runtime](https://vercel.com/docs/functions/runtimes/python).

Client `BACKEND_BASE_URL` is public configuration, never a credential. Gemini keys stay in backend environment settings. `AI_PROVIDER=disabled` and an empty model are the baseline. Public AI stays disabled until verified individual access for an eligible adult beta and bounded requests exist. CORS and an embedded shared app token cannot provide authentication.

Guests keep history/saved data locally. Optional password accounts may sync only
a bounded private display name/saved/history snapshot. Dietary/health preferences,
photos/raw OCR, appearance and Welcome completion remain on the phone/browser. v0.4.0 stores structured public observations automatically,
with private provisional staging and keyed anonymous write ownership. Confirmed
compatible exact candidates may be public with an explicit unreviewed label;
known conflicts/identity mismatches await exact-hash operator review. Semantic
deduplication avoids repeated revisions/review for identical rescans. Moderator
state never proves safety or the caller's current packet.

Firebase Unlabel has its free Standard `unlabel` database configured, with no
linked billing, verified anonymous/email-password Auth and denied direct client access. No paid
fallback is permitted. Source originals remain intact and incompatible nutrition
revisions stay unselected. [Community catalogue](COMMUNITY_CATALOGUE.md)
· [Privacy](../SAFETY_PRIVACY.md).


Widget/source checks and the current workflow do not prove OCR quality, native device behavior or dietary suitability. Current backend hosted evidence is recorded separately; local saved reports retain their date. Validate each new capture/sync flow during its implementation.

The independently released v0.2.3 slice provides the unchanged export-origin rich-facts catalogue: complete official JSONL stream -> bounded tracked India projection -> verified build-time SQLite/receipt. The separate facts route preserves direct nutrition sources, tag availability, optional record dates and official image attribution. Legacy aggregate nutrients remain unavailable as direct evidence; no image bytes are bundled. It does not replace the live OFF product/nutrition routes or fetch OFF on a snapshot miss. `/v1/catalogue` and metadata expose manifest, artifact summary, field limits and freshness based on the source export date. Manual replacement is every nine calendar months through reviewed source changes and a new immutable deployment, with previous-deployment rollback. Coverage remains unverified. [Implemented catalogue workflow](CATALOGUE.md).

The v0.3.0 numerical claim scope applies to confirmed ordinary general foods with a matching selected table/form/preparation. Missing/conflicting evidence and unknown fibre alternatives remain insufficient. Claim-specific statutory energy uses original rows and 4.2 kJ/kcal; normalization-v1 retains 4.184. No health score, complete legal certification, provider call or scan persistence follows from claim evaluation. [Reviewed source scope](../../knowledge/README.md).
