# Backend v0.5.0: Useful Label Report

Accepted continuation after the separately pushed, hosted-verified and published
v0.4.0 catalogue. Goal: one sourced report works from a barcode or corrected
back-package fields even when identity, nutrition, knowledge or saving is partial.
Flutter remains 0.0.0+1. No custom training, Gemini or universal health score.

## Contracts and evidence

POST `/v1/reports/check` takes a confirmed `ContributionRequest` observation,
optional selected table and optional existing claim applicability context.
Barcode may be null; ingredient-only evidence is useful. Reuse original rows and
normalization; do not generate missing nutrients from generic foods or other
formulations. Preserve ordered ingredient/contains/may-contain sections and their
completeness. Missing/not-observed declarations never mean allergy-safe.

Whole-string aliases identify a bounded subset of printed claims. Unknown and
negated wording stays unknown. Reuse the reviewed claim engine only when current
confirmed rows, one selected table and applicability context suffice. Missing,
conflicting or anomalous values block confident claim findings. An insufficient
claim section does not discard useful ingredients or numeric facts.

Sugar illustration states its original table basis/preparation, exact source rows,
total versus added sugar and a fixed **4 g per cube** approximation. A 40 g quantity
is not automatically one serving; package size is never a serving conversion.
Zero differs from missing. No mixing tables or mass/volume conversion by guessing.

GET `/v1/products/{barcode}/report` reuses exact OFF/community resolution. Historical
sources stay historical and cannot establish current-label claim confirmation.
Return 200 when a useful source exists, 404 when both definitively miss and 503
when no useful source exists because retrieval is unavailable.

## Ingredient explanations

GET `/v1/ingredients/glossary` exposes a bounded preinstalled three-entry
English/Hindi name/function glossary with exact source metadata and an integrity
hash: lecithin INS 322(i), citric acid INS 330 and xanthan gum INS 415.
Matching preserves original spans; bare numbers, partial words and unsupported
subtypes do not match. Unknown ingredients retain their original text.
The official Codex references support technological functions, not a health,
allergy, Indian regulatory permission or category verdict. Hindi text is a
reviewed project translation. No source fetching is performed in report requests.

## Automatic saving and availability

Current confirmed public observations save automatically through the existing
anonymous-token/HMAC/store path; no Share flag exists. Analysis itself needs no
authentication. Storage is a separate typed outcome (saved receipt,
authentication required, unavailable, rate-limited, conflict or needs correction).
Failed saving keeps the report usable. Frontend later retries the same immutable
submission through its bounded outbox. GET reports and glossary are read-only.

Existing 32 KiB actual request limits, strict numbers, redacted errors, no-store
responses, provenance/licenses and admission quotas remain. No new env secret,
provider, billing account, Storage, Function, paid TTL or private image retention.
Refresh `.env.age` when version/settings change; recoverable safe clones keep
community disabled until credentials are explicitly restored.

[Master plan](../../planning/MASTER_PLAN.md) ·
[Implementation plan](../plans/2026-10-07-backend-v0.5.0.md).
