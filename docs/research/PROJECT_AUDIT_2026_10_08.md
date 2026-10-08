# Repository audit — 8 October 2026

Scope: all tracked and intended new repository files, plus current frontend,
backend, documentation, release scripts, contracts and Vercel projects. Ignored
SDKs, generated builds/databases and private local settings are not source files.

## Findings fixed

| Finding | Fix / evidence |
| --- | --- |
| Android camera waited for gallery recovery before preview | Concurrent recovery with immediate camera start; timeout and stale recovered-photo regressions |
| Exact-source choice retained a legacy basis label | Card basis follows the selected exact table; comparison widget regressions |
| Ingredient evidence exposed only source identifiers | Source title, copyable URL and date in the detail dialog; red/green UI regression |
| Unsupported Unicode INS subtypes/word suffixes matched reviewed entries | Unicode/format boundaries and canonical source pin; glossary/API regressions |
| A long whitespace INS token could raise a report validation error | Bounded matching and no adjacent whitespace backtracking; maximum-input API regression |
| Preview proxy omitted the comparison route and used the wrong budget | Current OpenAPI route regression, 64 KiB comparison/512 KiB sync limits |
| Incomplete OCR manifests passed verification | Require all 21 exact trusted assets, metadata, sizes and hashes; 26 regression checks |
| Default OFF request identity still named v0.7 | Derive current backend version; preserve explicit override; provider request regression |
| Current docs described implemented OCR/login and hosted v0.8 as pending | Refresh active docs; preserve dated reviews and source implementation identities |
| Comparison tests failed configured static typing | Precise optional/union assertions; configured Pyright reports zero issues |
| Frontend build at backend commit `5ed899e` expected one fixture ingredient, but the expanded fixture matched four | Corrected the exported-contract expectation; final 181-test frontend suite passed. The frontend implementation push supplies this compatibility fix; the intermediate failed build did not replace the prior production frontend |

## Validation boundaries

- Backend: 1058 passed, 5 explicit live-provider skips; Ruff/Pyright clean;
  network-free 24,641-product catalogue and claim receipt build passed.
- Frontend: 181 tests passed; analyzer and release web/Wasm dry run passed.
- Source audit: 105 Python/106 JSON/99 Markdown files and 631 local links parsed
  without errors before production receipt additions. All 613 source files were
  inventoried; 541 UTF-8 texts checked for conflicts/fences/images. Binary source
  bundles remain covered by format/provenance/hash/build validation.
- YAML, nine embedded workflow shell scripts, TOML, 36 XML/SVG, four plist and
  bash checks passed; both PowerShell scripts parsed. Script Ruff and JS syntax
  checks passed, as did four local OCR bridge tests, 42 icon and 21 OCR hashes.
- Local maximum-size comparison/glossary microbenchmarks are recorded in the
  backend review. They do not establish hosted/mobile performance percentiles.
- Staged source scans found no actual local credentials or ownership secrets.

Hosted and rendered closure evidence is added after verification. Physical camera,
OCR accuracy, real account conflict reconciliation and provider/device behavior
remain separate acceptance gates, not implied by passing software tests.

[Backend review](../planning/BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](../planning/FRONTEND_V0_4_0_REVIEW.md).
