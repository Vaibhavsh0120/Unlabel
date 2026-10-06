# Decision 003: Open Food Facts and online-first analysis

Date: 5 October 2026. Historical decision record. The user selected Open Food Facts for product-data heavy lifting, reviewed FSSAI criteria for backend checks, and limited offline features. This supersedes Decision 002's required device-side rule evaluator/parity scope. Later implementation and release authorization are recorded in the [current development guide](../planning/LOCAL_DEVELOPMENT.md) and [current review](../planning/BACKEND_V0_3_0_REVIEW.md); the foundation-only authorization below describes the original decision date.

## Accepted direction

- Open Food Facts is the selected planned read-only barcode product-data provider.
- FastAPI's `app/providers/products/` adapter owns upstream requests and returns a stable Unlabel schema to all Flutter targets.
- Provider data remains source-tagged draft enrichment. The confirmed package governs scan evidence; reviewed sources govern criteria.
- The MVP is online-first. Python owns rule evaluation; no duplicate Dart rule engine is required. OFF-record checks and current-package-confirmed checks identify their evidence basis and do not guarantee complete legal compliance.
- Limited offline features are saved dated reports/product snapshots, local preferences and an optional small glossary. New lookup/analysis needs a reachable backend; OFF failure can fall back to sufficient confirmed package fields on that backend.
- Preserve attribution/license obligations, provider revisions, nutrient units/bases and field provenance. No automatic product/photo/correction uploads.

See the [complete workflow](../architecture/OPEN_FOOD_FACTS.md). Provider selection is no longer undecided; individual lookup use is conditional on connectivity and user workflow.

## Foundation and release boundary

Only documentation changes are authorized now. No API/plugin/dependency/app/workflow files change, and no APK/IPA rebuild is needed.

At the user's request, amend the existing foundation commit without changing its message. Keep the published `v0.0.0` tag and assets on their original build commit so release provenance/checksums remain accurate. The amended `main` commit includes this documentation update; it is not the source recorded in the existing release manifest. Future releases use their own source commit.
