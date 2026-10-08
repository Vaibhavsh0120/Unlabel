# Backend v0.8.0 — Sourced Nutrient Comparison

Working implementation on `main`, 8 October 2026. Backend v0.8.0 adds one
read-only selected-table comparison operation while preserving the independently
published v0.7.0 account/public contracts. The source is now pushed and exact-commit hosted proof is recorded below;
source-release publication is not established by that proof.

Backend v0.8.0 was pushed from `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` and hosted-verified with 25 checks at READY deployment `dpl_651iY8R8Dj6wNEdVC71Kw3ZW4oig`; its source-release publication is not established by that receipt.
[Production receipt](../research/BACKEND_V0_8_0_PRODUCTION.json).
The 8 October follow-up independently rechecked deployment identity and current
production meta. Later version checks do not replace this historical receipt.

## Delivered scope

`POST /v1/reports/compare` accepts two strict current-confirmed label inputs or
exact historical OFF/community references. Each side selects one table. Current
facts require explicit confirmation and work without authentication, catalogue or
cloud storage. Historical references pin an OFF snapshot ID/source hash or an
active public community revision/factual hash; missing, changed and unavailable
references return explicit states without substitution or private staging access.

Compatible known measured quantities in the same mass/volume unit and preparation
scale to 100 g or 100 mL. Exact rational arithmetic starts from original rows,
preserving zero, unknowns, duplicates, conflicts, bases, dates and source
qualifications. Eleven separate nutrient names remain stable. Scientific energy
conversion is versioned at 4.184 kJ/kcal; statutory claim conversion remains its
separate unchanged 4.2 contract. Signed differences are `b - a`; a numeric lower
value does not establish a winner, score, health, safety or compliance verdict.

The request has a 64 KiB actual-byte limit, strict raw-number validation and
redacted bounded errors. Responses use `no-store`; comparison performs no writes,
live OFF call, private sync or authentication lookup. Public lookup work is
bounded to at most two unique source resolutions. Existing impossible-quantity
checks are shared with report parsing without changing report behaviour.

See the complete [comparison contract](../architecture/SOURCED_COMPARISON.md).
Frontend v0.3.0+4's local OCR supplies editable suggestions and corrected confirmed
facts to the existing report API. It needs no photo/OCR upload endpoint. Its
native acceptance and new server-comparison integration remain separate frontend
gates; backend-only work does not rebuild APK/IPA artifacts.

## Local evidence

- Twenty-five focused comparison unit/ASGI tests passed; the final affected rerun
  completed in 1.82 seconds after the body-limit wording, actual chunked 413
  assertions and type narrowing changes.
  They cover exact unit/basis conversion, signed differences, explicit zero,
  unknown/conflicting inputs, preparation and mass/volume mismatches, strict
  confirmation, reference rotation, public-only community access, deduplicated
  reads, source outage, independent readiness, CORS, redacted validation and
  request-byte limits. Current-label tests reject any provider/store callback.
- The complete backend suite passed **975 tests with five emulator-only skips**
  in **50.08 seconds**, before that bounded transport/type follow-up. One upstream
  Starlette/httpx deprecation warning remains. Ruff application/test checks are
  clean, and application Pyright reports **0 errors / 0 warnings / 0 informations**.
  Ruff/Pyright were clean again after the affected rerun. Emulator-only skips and
  native/device behaviour are not claimed as executed.
- Contract generation adds `backend-v0.8.0.openapi.json`, two comparison schemas
  and two comparison examples: **21 paths / 22 operations**, **29 validated
  synthetic examples**. Earlier versioned OpenAPI files remain preserved. Current
  report/private-sync fixtures identify the new backend version without changing
  their contract shapes.
- Earlier v0.7.0 tests, hosted proof and publication remain historical evidence in
  the [v0.7.0 review](BACKEND_V0_7_0_REVIEW.md). They do not prove this deployment.

## Release gates

1. Complete contract regeneration and workspace Markdown/script/local-link/private
   data checks; the recorded full suite and affected follow-up are passing.
2. Review affected source and remove only confirmed dead code. Preserve teammate
   edits, historical release boundaries and exact implementation SHA provenance.
3. Update component docs before its independent push. Verify the exact new backend
   deployment is READY; test hosted version/meta/OpenAPI, source-compatible and
   incompatible synthetic comparisons, no-store, CORS and bounded validation.
4. Record the actual hosted receipt and tested source SHA, then publish the
   independent backend v0.8.0 source release. Documentation-only closure commits
   must remain distinguishable from the implementation SHA.

Firebase remains the existing free named database with no linked billing/card.
Photos/raw OCR remain on-device, dietary health preferences stay outside private
sync, Gemini stays disabled and no new reviewer/admin app role is introduced.
Local validation does not establish physical camera, iOS, emulator or hosted
provider behaviour that has not been exercised.
