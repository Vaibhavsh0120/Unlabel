# Useful Label Report

Current backend **v0.12.0** preserves `label-report-v1` and its source/confirmation
boundaries. Frontend **v0.7.0+11** integrates reports, six-entry ingredient detail,
original-basis sugar cubes, sourced comparison and captured/OCR results. Photos
stay session-local unless optional cloud transfer is consented; machine proposals
use a different unverified contract. [Data flow](DATA_FLOW.md) ·
[AI boundaries](AI_ROUTING.md).

## Historical introduction — backend v0.5.0

Production **v0.5.0** was independently reviewed, pushed, hosted-verified and
published after the separate v0.4.0 release. [Twenty hosted checks](../research/BACKEND_V0_5_0_PRODUCTION.json)
verified real reports, anonymous saving/retry, correction-blocked writes,
historical evidence, glossary boundaries and unchanged source receipts. The
report connects confirmed normalization, reviewed numerical claims and exact
sourced product facts. Frontend v0.1.0 implements manual current/historical report UI and automatic confirmed structured intake; its final rendered/release checks remain separate. Camera/OCR and reference-style screen redesign remain subsequent work.

## Three additive APIs

| Endpoint | Purpose |
| --- | --- |
| `POST /v1/reports/check` | Report from corrected confirmed structured package facts; barcode may be null; automatic storage has a separate outcome |
| `GET /v1/products/{barcode}/report` | Read-only report from exact historical OFF/community sources |
| `GET /v1/ingredients/glossary` | Read-only reviewed six-entry English/Hindi ingredient name/function glossary |

Current report input is `ReportCheckRequest`: a confirmed `ContributionRequest`
observation, optional `selected_table_id` and optional existing claim `context`.
Analysis needs no account or token. Public storage eligibility is stricter than
private analysis: missing front/back/pairing confirmation or barcode must not
discard useful corrected ingredients/nutrient information.

The `LabelReport` preserves report/backend/knowledge/glossary versions, generation
time, evidence basis, original observation or resolved source groups, nutrition,
claims, ingredient/declaration sections, glossary matches, missing inputs and
warnings. A `partial` report can still be useful. Missing sections/nutrients stay
unknown; no universal health score or allergy/compliance verdict is introduced.

## Current versus historical evidence

POST reports use `assessment_basis: user_confirmed_label` and original corrected
rows. Known exact whole-string printed claims map to the existing reviewed engine
only with confirmed front/back pairing and sufficient selected-table/applicability
context. Unknown, negated or
unsupported claims remain unassessed/insufficient. A missing claim or glossary
section must not hide usable label facts. Partial ingredient/contains/may-contain
sections retain their completeness; absence does not establish allergen absence.

GET barcode reports use `assessment_basis: catalogue_historical`, preserve exact
OFF/community originals and qualified source fields, and do not run historical
facts as current-label claim assessments. Compatible selected cells retain their
source IDs, bases, preparation, dates and alternatives. Conflicting/unknown
revisions are not silently combined. Generic IFCT/INDB/USDA composition never
supplies branded-packet gaps. GET is read-only, including storage outcome.

## Sugar illustration

Known total sugar can be illustrated with the fixed versioned assumption
**4 g per cube**, marked approximate. Preserve original source table, row IDs,
preparation and basis; distinguish total sugar from added sugar. A 40 g quantity
is not automatically a serving, and package quantity never supplies serving size.
Do not mix tables, guess density or hide a missing/conflicting sugar value.
Zero sugar is a known value; missing sugar produces no invented cube count.
For example, confirmed 12 g sugar per 40 g quantity produces approximately three
cubes on that original basis. It must not display the normalized per-100 g amount
as though it were the original portion.

## Small reviewed ingredient scope

Current version `ingredients-2026-10-08.1` contains six reviewed entries:
lecithin **INS 322(i)**, citric acid **330**, xanthan gum **415**, guar gum **412**,
sodium benzoate **211** and potassium sorbate **202**. The earlier three-entry
projection remains historical.
English/Hindi aliases preserve matched original text spans. Bare numbers,
partial words and unsupported INS subtypes do not match. Other ingredients keep
their original text with no fabricated explanation. This is **partial ingredient
coverage**, not a complete ingredient explorer or bilingual report.
Aliases require complete words, including their Unicode combining marks; an
unknown longer Hindi word cannot inherit a shorter ingredient's explanation.

The [current source check](../research/INGREDIENT_GLOSSARY_V0_9_0.md)
records exact official canonical records, source rights and projection hashes.
The bounded tracked `app/reports/glossary-v2.json` projection records official
Codex GSFA URLs, review date and function-only scope. A hash/byte/count artifact
appears in metadata and report/glossary responses. Bilingual descriptions are
independently authored explanations, not official Codex translations.
The sources do not establish allergy status, Indian category
permission, nutritional benefit or product safety. No glossary request fetches
regulations or requires a provider key.

The only app identity role is the scanner/client user with automatic anonymous
Firebase auth. No reviewer/admin app account or dashboard is introduced. The
service account is a backend machine credential; CLI conflict maintenance is
separate manual tooling and does not gate safe compatible ordinary observations.

## Automatic storage is independent

After current-label analysis, the API attempts the existing authenticated
community intake automatically. There is no Share flag. `storage.status`
distinguishes `saved` (with private receipt), `authentication_required`,
`unavailable`, `rate_limited`, `conflict`, `needs_correction` and GET `read_only`.
A missing token, disabled Firebase, quota or store error does not erase a useful
report. A caller can retry the same immutable observation without changing its submission identity; saving does not make historical data current or confer review trust.
Photos/raw OCR/profiles/history remain excluded.

Implausible or contradictory nutrient quantities also stop automatic saving with
`needs_correction`, while retaining the useful report. Examples include more than
100 g of a nutrient per 100 g, added sugar exceeding total sugar, or saturated fat
exceeding total fat. Correct those rows before retrying.

## Integration and historical release gates

Retain actual 32 KiB bodies, strict numeric tokens, redacted failures and no-store
responses. Read `/v1/meta` versions and capabilities before integration; glossary
readiness is separate from report and reviewed claim readiness. In the historical v0.5.0 release, no Gemini,
custom training, new provider, new secret, paid database/service or mobile build
belongs to v0.5.0. Preserve the fifteen released v0.4.0 APIs and historical exports.
The historical eighteen-route OpenAPI and four added schemas are exported with five
new report/glossary examples, bringing the validated synthetic set to 22.

[Accepted design](../superpowers/specs/2026-10-07-useful-label-report-design.md)
· [Implementation plan](../superpowers/plans/2026-10-07-backend-v0.5.0.md)
· [Historical review](../planning/BACKEND_V0_5_0_REVIEW.md)
· [Release scope](../planning/BACKEND_V0_5_0_RELEASE.md)
· [Current API guide](../../backend/README.md) · [Feature tracker](../planning/FEATURE_TRACKER.md)
