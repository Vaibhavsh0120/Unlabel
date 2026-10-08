# Sourced comparison and reviewed ingredient functions implementation plan

Updated **8 October 2026**. The user requested planning, implementation and
independent pushes of the next frontend and backend versions on `main`.

**Goal:** Deliver frontend **v0.4.0+5 Sourced Comparison and Ingredient Detail**
and backend **v0.9.0 Reviewed Ingredient Functions** using the existing free stack.

**Architecture:** Extend the existing Flutter Compare/report views and FastAPI
glossary/report contracts. Comparison uses the v0.8.0 read-only endpoint with
exact source and selected-table references. Ingredient explanations remain a
bounded reviewed fact projection, with original source references and partial
coverage. No new service, model, authentication role or database is required.

**Tech stack:** Existing pinned Flutter/Dart and FastAPI/Pydantic; no dependency
upgrade. Official Flutter/FastAPI documentation was fetched through Context7.
Better Design guidance supplies accessibility, loading and plain-copy checks;
the existing `DESIGN.md` brand and icon system remain selected.

**Specification:** This plan refines the v0.4.0/v0.9.0 slices in
[the accepted release roadmap](FRONTEND_BACKEND_NEXT_VERSIONS.md),
[master plan](MASTER_PLAN.md), [tracker](FEATURE_TRACKER.md) and
[comparison contract](../architecture/SOURCED_COMPARISON.md).

## Global constraints

- Work on `main` only; stage/review/document/push each component independently.
- Preserve teammate edits, historical projections/OpenAPI/source identities.
- Keep the project free with no billing/card requirement; Gemini stays disabled.
- Preserve Scan Label layout and Home / Scan / Compare / Saved navbar.
- Keep photos/raw OCR and dietary health preferences out of sync and API requests.
- Missing/conflicting facts never establish zero, health, allergy safety,
  Indian permission, compliance, a universal score or a winner.
- Native OCR accuracy, automatic live barcode detection, highlights,
  notifications and persistent comparison totals remain future gates.

## Review focus

- A restored current-label report lacks the original confirmation envelope:
  require label review again rather than fabricate confirmations.
- Product/table/swap/namespace changes during a request must invalidate old
  differences; late completions and disposed views must remain harmless.
- Historical references must pin actual OFF/community source/table identity,
  never a synthetic merged table or silently substituted source revision.
- Similar INS subtypes, Unicode word suffixes and mismatched source references
  must not produce unsupported ingredient explanations.
- Mobile, dark mode and doubled text must retain readable values, meaningful
  unknown/error states and reachable controls.

## Task 1: Reconcile the v0.8.0 baseline

- [x] Check the existing untracked hosted receipt against current meta/OpenAPI
  and Vercel deployment identity, preserving the receipt unchanged.
- [x] Correct pending-versus-pushed documentation without changing historical
  v0.7.0/v0.3.0 proof or inferring unpublished source-release status.

## Task 2: Backend v0.9.0

**Owner/files:** Backend worker owns `backend/`, the contract exporter and
generated JSON; coordinator owns shared documentation and release staging.
**Consumes:** Reviewed individual official Codex GSFA name/INS/function facts.
**Produces:** Six-entry bilingual glossary at existing routes, versioned artifact
and current OpenAPI/examples; historical `glossary-v1.json` remains unchanged.

- [x] Add failing tests for three new exact bilingual/name/INS matches,
  unsupported subtypes, entry-to-source mapping and immutable caller copies.
- [x] Verify official source references and record retrieval/review/projection
  hashes. Store paraphrased factual functions, never copied source articles.
- [x] Implement the new bounded projection and strict registry validation;
  preserve explicit unavailable/conflicting report outcomes and partial coverage.
- [x] Bump backend to 0.9.0; regenerate contracts while retaining old OpenAPI.
- [x] Run focused/full backend pytest, Ruff, Pyright and network-free build.
- [x] Independently review changes, update component/shared docs, explicitly
  stage backend/contracts/docs and push the backend commit on `main`.
- [x] Check exact hosted deployment and synthetic glossary/report/meta contracts;
  record actual results separately from local source/test proof.

## Task 3: Frontend v0.4.0+5

**Owner/files:** Frontend worker owns `frontend/lib/` and `frontend/test/`;
coordinator owns version, documentation, build and rendered checks.
**Consumes:** Existing v0.8.0 comparison and label-report glossary contracts.
**Produces:** Exact-source comparison requests, validated response rendering,
source-aware table choices and bilingual ingredient details in existing screens.

- [x] Add failing DTO/request/repository tests for exact source pins, current
  confirmation privacy, eleven nutrient cells, echoed request/session/revision,
  invalid numeric data, capability failures and no authentication callback.
- [x] Preserve the exact confirmed request in client session memory separately
  from report `raw`; never serialize into local history/private sync. Restored
  current reports explicitly require review again for sourced comparison.
- [x] Integrate original source/table selection, per-100 amounts, source/date
  qualifications and unknown/incompatible reasons into existing Compare cards.
  Clear/invalidate results on selection/swap/namespace/disposal and support retry.
- [x] Add a readable ingredient detail interaction with English/Hindi functions
  and actual evidence links, preserving partial coverage and existing disclaimers.
- [x] Test stale completions, changed sources, failures/retry and serialization
  boundaries. Bump frontend to 0.4.0+5; run full Flutter tests/analyzer/web build.
- [x] Inspect rendered mobile/desktop light/dark/enlarged text states; run Better
  Design review/comprehension/spacing with the Flutter-canvas DOM limit recorded.
- [x] Independently review changes, update component/shared docs, explicitly
  stage frontend/docs and push the frontend commit on `main`.
- [x] Verify deployed frontend version/source/assets and observable browser
  behavior; record remaining native/physical-device gates accurately.

## Completion evidence

The user's camera-delay follow-up adds parallel Android lost-gallery recovery
and immediate preview initialization, with revision guards for late results.
Capture resolution and the existing Scan Label layout remain unchanged.

Each component review records exact commands/results, limitations, implementation
SHA and push state. A successful local check is never substituted for hosted or
physical-device evidence. The coordinator reports both pushed commit identities.
