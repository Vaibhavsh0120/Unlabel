# Backend v0.2.0 review

Checked **5 October 2026**. Frontend remains **v0.0.0**. This record separates synthetic checks, live provider evidence and production verification.

## Local verification

| Check | Result |
| --- | --- |
| Full pytest suite | 120 passed; one existing Starlette/HTTPX TestClient deprecation warning |
| Ruff source/test/export-tool checks and formatting | Passed |
| pip dependency consistency | No broken requirements |
| Strict v0.1.0 product schema/example compatibility | Exact schema unchanged; historical example validates |
| Nutrition schema/examples | Generated from models; three owned synthetic examples validate |
| Pure normalization | Units/bases/preparation, zero/unknown, no inference, duplicate/conflict states, conversion overflow/underflow |
| Request/provider bounds | Real ASGI multi-chunk budget, declared/streamed oversize, finite/faithful JSON numbers, unknown/private fields, truncated/redacted validation errors, 64-row output bound |
| Local TCP HTTP smoke | Health/meta v0.2.0; confirmed POST gives 10 g protein/100 g from synthetic 4 g/40 g; oversize 413; live OFF-backed nutrition GET 200 with three separate tables |

No Flutter/mobile build was run for this backend release. The source tests do not prove device OCR, full Indian market coverage, legal applicability, food safety or unlimited hosted capacity.

## Live OFF feasibility, checked before assuming schema

The backend's existing bounded client fetched `3017620422003` (Nutella) in 0.68 seconds and `5449000000996` (Coca-Cola Original) in 0.18 seconds. Both returned `nutrition.input_sets` and product schema 1004, with direct manufacturer/packaging rows plus estimate tables. No API key was used.

The completed adapter also fetched both records: 0.81/0.17 seconds in that sample. It retained three supported tables per record, separated mass from volume/serving bases, and excluded computed/estimate rows. Later comparable-table disagreement detection and local HTTP smoke retained those facts with correction warnings. Times are single observations, not a latency guarantee. Live prepared-product coverage remains unverified; synthetic tests cover preparation separation.

One bounded India-tagged v2 search returned HTTP 503, no identities. The official data page returned 200 and documents global nightly exports/filtered CSV, but no dedicated India export URL was verified. No corpus, image or raw public response was saved. [Primary schema and feasibility research](../research/OFF_NUTRITION_V3_6.md).

## Review findings resolved

- Upstream 16-table input could exceed the 64-row snapshot budget: omit whole excess tables with an explicit warning instead of raising 500.
- Energy key/unit mismatch could normalize an ambiguous number: reject the row as unknown.
- JSON underflow/high precision could become zero or bypass the cap before model validation: reject unfaithful raw numeric tokens at ingress. Catch exceptional decimal exponents and map them to sanitized validation/provider failure states.
- Unbounded validation errors could amplify a small request: expose at most 32 entries, redact extra-key names/values and mark truncation.
- An empty table could invent a synthetic original row: retain an all-unknown table with no fabricated original rows.
- Comparable provider tables could disagree without a warning: retain both tables and flag review; never choose a silent winner.

## Production gate

Source commit `2d6763674f737b3b171e207b915f24f1ee33a227` automatically produced READY production deployments for both projects:

- Backend `dpl_Dc6jieG7Z1ARefhDF4aXFyhUUznR`, aliased to [unlabel-api.vercel.app](https://unlabel-api.vercel.app).
- Website `dpl_67K6LAYYWGxBNk8uTYHLuZdPQGXZ`, aliased to [unlabel-india.vercel.app](https://unlabel-india.vercel.app). Flutter source/version remain 0.0.0+1; public HTML/title and release JavaScript returned 200.

Public HTTPS checks used no Vercel login/bypass cookie: health/meta returned 200 and backend version 0.2.0; live OpenAPI exactly matched the exported schema; confirmed POST returned 200 and the expected synthetic 10 g/100 g; private fields and exceptional numeric tokens returned sanitized 422; oversized body returned 413 with exact-origin CORS; POST/Content-Type preflight passed; an unrelated origin was not allowed. Invalid nutrition barcode returned 422. OFF-backed Coca-Cola nutrition returned 200 with three preserved tables and correction status; the existing Nutella product route returned 200.

Markdown local links were checked across 43 tracked files, with no missing targets. This evidence is recorded before the final documentation push. That docs-only push redeploys identical backend/frontend source; the GitHub release records its final tag/commit and publication state. These checks establish this release's production behavior, not Indian export feasibility, device integration or provider uptime guarantees.

## Deferred gates

India export size/import/storage and six-month refresh (v0.2.1); reviewed FSSAI rules/evidence; scanned-package confirmation UI; raw OCR/photos/geometry; ingredient translation/comparison; access/abuse control before any optional AI; real-device/offline/client features. No new credentials are needed for this version.
