# Decision 002: shared Flutter targets, offline scope and manual releases

Date: 5 October 2026. This supersedes the client/deployment assumptions in Decision 001 as the user refined the scope. Its required offline-evaluator scope is subsequently superseded by [Decision 003](003-open-food-facts.md); retained below as decision history.

Implementation has since progressed beyond this historical foundation decision. Use the [current status and recovery guide](../planning/LOCAL_DEVELOPMENT.md) and [Vercel record](../planning/VERCEL_SETUP.md) for today's backend/deployment state.

## Accepted scope

- One Flutter app directly in frontend, targeting Android, iOS and web.
- iPhone, iPad portrait/landscape and MacBook-sized layouts in both light/dark modes. No final color theme selected.
- Two future Vercel projects: Flutter website and Python/FastAPI backend. Mobile clients use the same stable HTTPS backend.
- Supported offline OCR/glossary/templates/rules/history, with explicit missing-data/unsupported-rule uncertainty. Website offline needs an initial load and explicit cache/service-worker work.
- One canonical reviewed declarative rule set; a supported Dart client evaluator and optional expanded Python evaluator must share parity fixtures and versioned coverage.
- Existing AI/OCR models first; no custom training required. Hugging Face is optional research subject to current eligibility and quota constraints.
- Basic Flutter starter and an executable manual APK/unsigned-IPA release workflow now authorized and created.
- User requested final review, GitHub push and the first v0.0.0 release through that manual workflow.

## Boundaries

The scanner, evidence corpus, rule evaluators, backend and Vercel deployment remain future work. Unsigned IPA means a device build packaged without signing; it is not directly installable. APKs currently use demo debug signing and do not establish a permanent production/update identity.

Canonical product version lives in frontend/pubspec.yaml until shared release metadata is expanded. Workflow overrides are recorded for both artifacts, never independently chosen per platform. Native releases and backend/web deployments may differ in source SHA while remaining contract-compatible.

This decision records evolving user instructions; no paid account, signing membership, trained model, backend service or website deployment is implied.
