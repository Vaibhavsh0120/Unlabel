# Backend language options

Language/provider research checked: **2026-10-05**. Implementation status updated for **backend v0.2.1**: **Python/FastAPI is selected** and implemented under `backend/app/`; Rust remains a deliberate later alternative. The backend supports live OFF product/nutrition lookup, confirmed-value normalization and an optional read-only identity catalogue. Frontend stays **0.0.0+1** with no API adapter; its mobile artifacts are unchanged. Reviewed rules, explanation templates and AI remain future work.

## Comparison

| Choice | Fit | Tradeoff | Decision |
| --- | --- | --- | --- |
| Python + FastAPI | Official Gemini Python SDK, accessible rule/validation tooling and teammate workflow | Requires careful runtime validation/dependency management | Selected |
| Rust + Axum | Typed HTTP API, deterministic evaluations and Gemini REST requests | Async Rust, ownership and crate/toolchain learning add work; verify hosting integration separately | Viable deliberate future change |
| Python + Rust hybrid | Could address a later measured specialized workload | Two toolchains and extra integration boundaries | Avoid for this mini-project |

Neither language requires custom model training. Camera/OCR belongs in platform-specific Flutter adapters. Neither language guarantees free hosting or unlimited provider requests. [FastAPI deployment](https://fastapi.tiangolo.com/deployment/), [Axum reference](https://docs.rs/axum/latest/axum/).

The FastAPI backend and Flutter website already have separate Git-connected Vercel projects. An existing laptop/private LAN remains a fallback. Version-specific production checks and catalogue availability are recorded separately from local source/import checks. Hobby eligibility and quotas must meet the ₹0/no-card constraint; do not upgrade to make a demo work. [Deployment plan](../architecture/DEPLOYMENT_PLAN.md).

## Shared architecture

Use language-neutral contracts in `contracts/` and canonical declarative rules/evidence under `knowledge/`. The online Python backend owns Unlabel's reviewed rule evaluation and English/Hindi template rendering. A duplicate Dart evaluator or mandatory Dart/Python rule parity is not required.

Open Food Facts is the selected read-only product-data provider. Its normalized product fields and computed insights do much of the product lookup/ingredient-data work, with explicit source/freshness. They remain distinct from Unlabel's backend FSSAI-related findings; confirmed package evidence cannot be silently overwritten. See [OFF integration plan](../architecture/OPEN_FOOD_FACTS.md).

Future public knowledge is packaged as read-only JSON in the deployed function; root build access alone does not guarantee runtime inclusion. The v0.2.1 product catalogue uses immutable SQLite built from validated local OFF JSONL or an official-CSV identity projection. It is enabled only with a valid configured catalogue directory. Full India coverage and hosted bundle fit require acquisition/import measurements. SQLite is not a hosted mutable user database; Firestore has not been selected, and instance memory and `/tmp` remain disposable.

Clients send confirmed public label fields/region IDs and public barcode lookup requests. Preferences, personal suitability, images and history remain local. `/v1/meta` exposes versions/capabilities. New analysis requires a reachable backend. Without it, retain local drafts and show dated saved reports, local preferences and an optional small preinstalled glossary.

For the ₹0/no-card demo, the same backend may run on an existing laptop/private LAN. With no external Internet, it can evaluate sufficient confirmed fields using packaged rules and templates; uncached OFF data and cloud AI are unavailable. Keep incomplete checks unknown. This is a reachable local backend, not a device-side offline evaluator.

Gemini receives only public product text, approved public snippets and generic findings. Model output cannot alter verdicts or references. Reviewed English/Hindi templates work without Gemini. Public AI stays disabled until verified individual adult-beta access and request bounds are implemented; no shared embedded app credential.

## Python direction

- Keep FastAPI handlers thin; services coordinate selected OFF product lookup, confirmed-field normalization, reviewed knowledge/rules and optional wording.
- Validate explicit request/response models and semantic consistency, not JSON shape alone.
- Use the official `google-genai` SDK behind a provider boundary; credentials remain backend-only.
- Bound provider input/output, concurrency, timeouts and retries; invalid/quota-failed calls retain templates.
- Test provider missing/unavailable data, dated saved reports, API compatibility and reviewed rule outcomes; do not require a second client-side rule engine.
- Preserve the implemented entrypoint, dependency manifests, packaging and regression tests while adding reviewed feature slices. Keep catalogue tooling and snapshot lookup separate from live nutrition and future rule evaluation.

Official guidance: [Gemini SDKs](https://ai.google.dev/gemini-api/docs/libraries), [Python SDK](https://github.com/googleapis/python-genai), [free-stack research](FREE_STACK.md).

## Rust alternative

If deliberately selected later, replace the Python backend with analogous `backend/src/` modules. Do not create two competing backend trees or a Python microservice only to call Gemini. Recheck Vercel runtime/deployment support before assuming Axum behaves like native FastAPI support.

Google's official SDK list did not list Rust on the research date; use its documented REST API behind a provider interface. [SDK list](https://ai.google.dev/gemini-api/docs/libraries), [API reference](https://ai.google.dev/api).

- Reuse one `reqwest` HTTP client in application state for connection pooling.
- Define typed Serde requests/responses, timeouts and bounded bodies/concurrency/retries.
- Validate factual values, outcome immutability and allowed evidence IDs after deserialization.
- Keep identical template fallbacks and read-only knowledge packaging; no managed/vector database is required.

Context7 resolved/queried `/tokio-rs/axum` and `/seanmonstar/reqwest` for state/client patterns. [Axum documentation](https://docs.rs/axum/latest/axum/), [reqwest client](https://docs.rs/reqwest/latest/reqwest/struct.Client.html).
