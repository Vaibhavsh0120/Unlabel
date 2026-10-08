# Backend v0.9.0 — Reviewed Ingredient Functions

Implementation on `main`, **8 October 2026**. This independent backend slice
expands the function-only English/Hindi glossary from three to six reviewed
entries while preserving existing report, comparison and private-sync routes.
Source push and hosted evidence are recorded only after those gates succeed.

## Delivered scope

- New versioned six-entry projection, preserving historical `glossary-v1.json`.
  Adds guar gum INS 412, sodium benzoate 211 and potassium sorbate 202. All six
  exact official Codex source URLs/functions were reviewed; independent authored
  bilingual explanations retain partial coverage and source qualifications.
- Exact entry/alias/code/own-source/review-date validation and canonical reviewed
  content pin. Malformed or altered knowledge fails closed. English/Hindi word
  boundaries and ASCII INS/E prefixes reject unsupported lookalikes/subtypes.
  Source and entry copies cannot mutate the loaded evidence.
- Existing 21 API paths / 22 operations remain. Current wire schema version 1
  permits the six known entries/counts; historical OpenAPI exports are preserved.
  Twenty-nine synthetic examples include the added matched ingredient facts.
- Production preview now forwards `/v1/reports/compare` with its 64 KiB limit;
  a regression checks every current OpenAPI operation instead of a stale v0.7
  route list. Private sync retains its separate 512 KiB request allowance.
- Repository review also found incomplete OCR provenance could pass `--check`;
  the asset verifier now requires the complete trusted asset/source manifest.

## Evidence and gates

Final full backend suite: **1058 passed, 5 skipped** in 75.72 seconds. The skips
are explicit live-provider gates. Backend Ruff and configured Pyright passed
with zero errors. The network-free catalogue build passed: 24,641 products and
the verified two-file claim receipt; no remote acquisition was performed.

The independent review found and resolved Unicode subtype/format-character
partial matches. Overlong INS matches now remain unknown instead of raising a
response validation error. The default OFF request identity now follows the
backend version while retaining explicit configuration overrides.

Twenty local timing samples of bounded inputs measured 13.1 ms for a maximum
length missing code, 20.8 ms for many matches capped at 64, 9.8 ms for combining
marks and 13.0 ms for two current tables with 64 rows each. Comparison made zero
provider/store calls. These are local microbenchmarks, not hosted or device SLAs.

The repository audit parsed 105 Python files, 106 JSON files, 99 Markdown files
and 631 local links without errors. All 613 tracked/intended files were scanned
for text/conflict/fence problems; 72 binary/compressed files have separate
format/hash/build checks. YAML/workflow shell/TOML/XML/plist/bash, script Ruff,
42 icon hashes and all 21 OCR hashes passed. The OCR verifier regression passed
26 tests. Independent backend review has no remaining blocker. Staged privacy
checks found no actual credentials or ownership secrets.

Pushed implementation: `5ed899e26941477f4b8c405da97ce5d297183e7d`.
Production deployment `dpl_92aS6GAdUEeyonoy2XYuQogyxoz7` is READY at that exact
source, assigned to `unlabel-api.vercel.app`. **26 hosted checks passed**, covering
health/meta/OpenAPI, exact glossary/example agreement, bounds, CORS and sourced
comparison. [Production receipt](../research/BACKEND_V0_9_0_PRODUCTION.json).
Later frontend/documentation commits retain this implementation identity.

[Implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md) ·
[Reviewed sources and hashes](../research/INGREDIENT_GLOSSARY_V0_9_0.md) ·
[Historical v0.8.0 proof](../research/BACKEND_V0_8_0_PRODUCTION.json).

Photos/raw OCR/dietary reminders remain outside sync. Gemini stays disabled and
Firebase retains its existing no-card/free configuration. No APK/IPA build is
needed for this backend release. No health/allergy/Indian-permission verdict,
complete ingredient coverage, physical-device or new live-cloud-write proof is
claimed by these software changes.
