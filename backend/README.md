# Backend — planned FastAPI service

Python/FastAPI is selected. No backend entrypoint, package manifest, dependency installation or database exists yet. The Flutter starter/manual native-artifact workflow is separate and already scaffolded.

Later deploy this directory as one stateless Vercel project; the Flutter website uses another project. An existing laptop/private LAN is an optional development/demo fallback. See [deployment plan](../docs/architecture/DEPLOYMENT_PLAN.md).

| Area | Planned responsibility |
| --- | --- |
| `app/api/v1` | Thin handlers, health and `/v1/meta` compatibility/capabilities |
| `app/core` | Settings, auth boundaries, limits, redacted logging and errors |
| `app/schemas` | Validated language-neutral contract models |
| `app/services/parsing` | Corrected label extraction, units and provenance |
| `app/services/analysis` | Expanded reviewed rule evaluation with explicit unknowns |
| `app/services/knowledge` | Canonical aliases and approved source lookup |
| `app/services/personalization` | Neutral reason catalog/facts; no personal profile storage |
| `app/providers/ai` | Template baseline and optional protected Gemini wording |
| `app/providers/products` | Optional source-tagged community enrichment |
| `app/prompts` | Future evidence-constrained wording instructions |
| `app/repositories`, `db` | Read-only packaged lookup; optional local derived index ownership |
| `storage/runtime` | Ignored local-laptop SQLite/cache artifacts, not hosted persistence |
| `tests/unit`, `tests/integration` | Future canonical-rule parity, contract and provider-failure checks |

The deployed function uses **bundled read-only JSON** derived from root `knowledge/`. A future packaging script must validate/stage required knowledge and version metadata; access to files outside the Vercel root does not itself package them. Do not store scans, profiles or durable counters in SQLite, memory or `/tmp` on Vercel.

The client evaluates a supported reviewed offline subset from the same canonical definitions and parity fixtures. Python adds expanded checks. Backend absence still permits supported new offline findings; unsupported checks remain `insufficient_information`. `/v1/meta` exposes contract, knowledge/rule versions and capabilities; reports retain their evaluator scope/version.

Only confirmed public text/fields and region IDs cross the API. Images, preferences, history and personal suitability stay local. Gemini may rewrite generic public findings using approved evidence; never alter deterministic numbers/outcomes/references. Reviewed English/Hindi templates remain usable when AI fails or is disabled.

[.env.example](.env.example) is an inert future-settings template. Gemini remains disabled until verified individual access for an eligible adult beta and bounded requests exist. A development `LOCAL_API_TOKEN` is not public authentication and must not ship in apps. CORS is not auth; clients receive only public `BACKEND_BASE_URL` configuration, never provider or shared access secrets.

No account creation, cloud deployment or paid billing setup is part of the current foundation. Hosted caches and request counters are disposable and cannot guarantee global quota protection.
