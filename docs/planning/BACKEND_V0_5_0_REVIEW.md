# Backend v0.5.0 review: Useful Label Report

Reviewed on **7 October 2026**. This version composes the existing confirmed-row
normalizer, reviewed claim rules and sourced catalogue into a usable report.
Flutter remains **0.0.0+1**. v0.4.0 was separately pushed, hosted-verified and
published before this work. Local checks and hosted publication are separate.

## Implemented boundaries

- Three additive routes return a confirmed-label report, a read-only exact-barcode
  historical report and a versioned ingredient name/function glossary. All
  fifteen released routes and strict identity/community contracts remain.
- Corrected ingredients or nutrient rows work without a barcode. Each original
  row, declaration, missing input, source and selected basis stays explicit.
  This version does not process photos or raw OCR.
- Known whole-string printed claims reuse the reviewed numerical engine only
  with sufficient confirmed paired package facts and applicability context.
  Unknown/negated wording, unavailable evidence, conflicts and impossible
  quantities cannot become supported claims. Historical catalogue facts never
  confirm the current package or establish a current-label assessment.
- Sugar uses the original printed total-sugar row and basis. The separately
  versioned illustration divides grams by an approximate four-gram cube; it
  never invents serving size, density or sugar amount from net package weight.
- The tracked, hashed glossary covers three English/Hindi ingredient functions
  with exact names and reviewed INS subtypes. It preserves original text spans
  and primary source references. Functions do not establish allergy safety,
  Indian legal permission or complete ingredient coverage.
- Anonymous client requests save structured public facts automatically through
  v0.4.0 storage. Authentication, admission, conflict and provider failures have
  typed storage outcomes; a useful analysis remains HTTP 200. Historical GETs
  do not write. There is no Share switch, admin/reviewer app role or dashboard.
- AI/model training and Gemini stay disabled. No new runtime dependency, cloud
  resource or paid service is required. The existing first Standard Firestore
  database **unlabel** and no-billing project remain unchanged.

## Review and local verification

Independent review reproduced two glossary word-boundary bugs: Hindi vowel signs
and join controls could allow an exact alias to match a longer word. Twelve
failing regression cases preceded the fixes; combining marks and join controls
now stay part of words. Another three failing cases showed impossible quantities
still admitted as public candidates despite report warnings. Authenticated
requests now return `storage.needs_correction` without a write, preserving useful
original facts in the report. Independent re-review passed **109 focused tests**
and found no remaining actionable issues. A redundant overwritten report-list
initialization was removed; its **26 service tests** passed afterward.

- Full backend suite: **807 passed, five emulator-only cases skipped**. Storage
  is unchanged from the separately verified five real v0.4.0 emulator cases.
- Pyright 1.1.414 over maintained backend/tests/scripts: **zero errors and
  warnings**. Ruff passed and all **84 Python files** were already formatted.
  Locked dependency consistency and whitespace checks passed.
- All **84 Python**, **77 JSON** and **76 Markdown** files parsed; **499 local
  Markdown links** resolved at the initial frozen-guide check; the final release
  records bring the validated local-link count to **507**. Both PowerShell entry
  points parsed successfully.
  One existing upstream TestClient deprecation warning remains non-failing.
- Actual backend setup restored locked dependencies, verified compressed/decoded
  source hashes and reused the 24,641-product index with progress bars. A
  networkless build retained the original OFF source and both canonical reviewed
  claim files. No acquisition or remote regulator fetch runs during a build.
- Contracts export eighteen routes, four new schemas and five new examples
  (**22 total**). Independent comparison found all fifteen v0.4.0 paths and all
  existing OpenAPI component schemas structurally unchanged.
- Actual local settings/age ciphertext and the public production OFF adapter
  version were updated. Existing Firebase resources/secrets and AI-disabled
  behavior remain. Unchanged Flutter checks passed during v0.4.0; no mobile build
  is part of this version.

## Hosted verification and publication

Pending the independently reviewed v0.5.0 push. Production still serves released
v0.4.0. Exact-commit deployment readiness, real report/glossary/saving requests,
existing source receipts and owned synthetic cleanup must pass before a v0.5.0
source-only release is published. No completion claim is based on local tests.

[Release scope](BACKEND_V0_5_0_RELEASE.md) ·
[Report architecture](../architecture/LABEL_REPORT.md) ·
[Ingredient source review](../research/INGREDIENT_GLOSSARY_V0_5_0.md) ·
[Master plan](MASTER_PLAN.md) · [Feature tracker](FEATURE_TRACKER.md).
