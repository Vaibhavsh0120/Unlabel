# Backend language options

Research checked: **2026-10-05**. **Python/FastAPI is selected** by the user for quicker implementation. Keep `backend/app/`; Rust is a viable later alternative. The backend remains planned, while the separate Flutter starter and manual native-artifact workflow exist.

## Comparison

| Choice | Fit | Tradeoff | Decision |
| --- | --- | --- | --- |
| Python + FastAPI | Official Gemini Python SDK, accessible rule/validation tooling and teammate workflow | Requires careful runtime validation/dependency management | Selected |
| Rust + Axum | Typed HTTP API, deterministic evaluations and Gemini REST requests | Async Rust, ownership and crate/toolchain learning add work; verify hosting integration separately | Viable deliberate future change |
| Python + Rust hybrid | Could address a later measured specialized workload | Two toolchains and extra integration boundaries | Avoid for this mini-project |

Neither language requires custom model training. Camera/OCR belongs in platform-specific Flutter adapters. Neither language guarantees free hosting or unlimited provider requests. [FastAPI deployment](https://fastapi.tiangolo.com/deployment/), [Axum reference](https://docs.rs/axum/latest/axum/).

The selected later deployment is a stateless FastAPI Vercel project, separate from the Flutter website. An existing laptop/private LAN remains a fallback. Hobby eligibility and quotas must meet the ₹0/no-card constraint; do not upgrade to make a demo work. [Deployment plan](../architecture/DEPLOYMENT_PLAN.md).

## Shared architecture

Use language-neutral contracts in `contracts/` and canonical declarative rules/evidence under `knowledge/`. Dart evaluates a supported reviewed offline subset; Python adds expanded online checks. Both use the same rule IDs, thresholds, applicability definitions and parity fixtures, rather than duplicate hand-maintained catalogs.

Package required public knowledge as read-only JSON in the deployed function. Root build access alone does not guarantee runtime inclusion. SQLite is an optional rebuildable local-laptop index, not a hosted mutable database; instance memory and `/tmp` are disposable.

Clients send confirmed public label fields/region IDs. Preferences, personal suitability, images and history remain local. `/v1/meta` exposes versions/capabilities. When the backend is unavailable, supported new offline findings still work; unsupported expanded checks remain unknown/pending.

Gemini receives only public product text, approved public snippets and generic findings. Model output cannot alter verdicts or references. Reviewed English/Hindi templates work without Gemini. Public AI stays disabled until verified individual adult-beta access and request bounds are implemented; no shared embedded app credential.

## Python direction

- Keep FastAPI handlers thin; services coordinate normalization, knowledge, rules and optional wording.
- Validate explicit request/response models and semantic consistency, not JSON shape alone.
- Use the official `google-genai` SDK behind a provider boundary; credentials remain backend-only.
- Bound provider input/output, concurrency, timeouts and retries; invalid/quota-failed calls retain templates.
- Add actual backend entrypoint, dependency manifest, packaging and tests in the implementation phase.

Official guidance: [Gemini SDKs](https://ai.google.dev/gemini-api/docs/libraries), [Python SDK](https://github.com/googleapis/python-genai), [free-stack research](FREE_STACK.md).

## Rust alternative

If deliberately selected later, replace the Python backend with analogous `backend/src/` modules. Do not create two competing backend trees or a Python microservice only to call Gemini. Recheck Vercel runtime/deployment support before assuming Axum behaves like native FastAPI support.

Google's official SDK list did not list Rust on the research date; use its documented REST API behind a provider interface. [SDK list](https://ai.google.dev/gemini-api/docs/libraries), [API reference](https://ai.google.dev/api).

- Reuse one `reqwest` HTTP client in application state for connection pooling.
- Define typed Serde requests/responses, timeouts and bounded bodies/concurrency/retries.
- Validate factual values, outcome immutability and allowed evidence IDs after deserialization.
- Keep identical template fallbacks and read-only knowledge packaging; no managed/vector database is required.

Context7 resolved/queried `/tokio-rs/axum` and `/seanmonstar/reqwest` for state/client patterns. [Axum documentation](https://docs.rs/axum/latest/axum/), [reqwest client](https://docs.rs/reqwest/latest/reqwest/struct.Client.html).
