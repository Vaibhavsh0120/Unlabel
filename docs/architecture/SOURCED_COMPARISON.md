# Sourced nutrient comparison v1

Backend v0.8.0 adds `POST /v1/reports/compare` as an independent read-only contract.
It preserves `label-report-v1`, private account sync and earlier public response
shapes. The implementation is in `backend/app/comparison/`; its exported schemas
and examples are listed in the [contracts guide](../../contracts/README.md).

## Inputs and source resolution

The strict request uses `schema_version: "1"`, UUID `client_request_id` and
`comparison_session_id`, a nonnegative strict integer `input_revision`, and sides
`a` and `b`. Each side selects exactly one `selected_table_id` and one source kind:

| Kind | Required evidence | Resolution |
| --- | --- | --- |
| `current_confirmed_label` | A strict structured `ContributionRequest` with `observation_state: confirmed`, real boolean `confirmed: true`, and manual or corrected-OCR capture | Normalize the supplied original rows; no provider, store or authentication call |
| `off_snapshot` | Exact barcode, snapshot ID, source SHA-256 and selected direct table | Read the active immutable OFF snapshot only; match both manifest ID and hash |
| `community_revision` | Exact barcode, active public revision ID, factual SHA-256 and selected table | Read only the active public candidate/accepted revision; match its factual hash |

Barcodes preserve leading zeros and retain the existing ASCII 8/12/13/14-digit
contract. Historical source references never become current-package confirmation.
The resolver reuses a lookup when both sides request the same kind/barcode, with
at most two source lookups for the request. It makes no live OFF request, performs
no public contribution/private-sync write and cannot expose private staged facts.
Unknown or rotated references do not fall back to a different source or revision.

The side result is `ready`, `needs_correction`, `not_found`, `source_changed` or
`unavailable`. A usable side retains its identity, source qualification, original
nutrition snapshot and selected table. Historical sides echo their requested
reference. Current sides expose the submission ID, observation date and capture
method as user-confirmed evidence, without claiming independent verification.
OFF sides retain the manifest, record date and packaging/manufacturer origin.
Community sides retain revision/factual hashes, observation/submission/review
dates, review state and CC0 qualification. The response does not repeat raw OCR,
photos or the complete current observation.

OFF legacy aggregates are unavailable for comparison; only direct packaging or
manufacturer input tables qualify. A missing or ambiguous selected table,
normalization correction requirement, impossible nutrient quantities, disagreeing
provider tables or unresolved public product conflict prevents subtraction.
Original rows and warnings remain available to explain the limitation.

## Comparable quantities

Both selected tables need a known measured amount in the same unit (`g` or `mL`)
and the same preparation (`as_sold` or `as_prepared`). A serving with an explicit
amount/unit can be scaled; an unknown serving size cannot. The common basis is
100 g or 100 mL. A gram basis cannot be compared to a millilitre basis without
density, and no density is inferred.

Calculations use exact rational values constructed from the original numeric
decimal strings and their original row bases. Conversion does not reuse rounded
normalized floats. Mass nutrients convert g/mg/ug to g; energy converts kcal/kJ to
kcal using **4.184 kJ/kcal**, version `nutrition-comparison-4.184-v1`. This is
distinct from statutory claim checks that use their separately versioned 4.2
conversion. Existing normalization and claims contracts are preserved.

The eleven ordered nutrient identities remain distinct: energy, fat, saturated
fat, available carbohydrates (`carbohydrates`), total carbohydrates, total sugars,
added sugars, fibre, protein, sodium and salt. No available/total-carbohydrate or
salt/sodium substitution occurs. No serving size, added sugar, ingredient amount
or missing nutrient value is inferred.

Each cell retains its original row IDs and either a bounded converted value or a
reason. Explicit zero is valid; a missing or explicitly unknown value stays
unknown. An unknown duplicate cannot be discarded in favour of a known row.
Identical known duplicate values can agree; conflicting values require correction.
Conversion overflow or a nonzero value underflowing to zero cannot produce a
number. Converted values and differences are bounded to a magnitude of 1 billion.

## Response outcomes

`comparison_version` is `sourced-nutrient-comparison-v1`. Request/session/revision
values are echoed so clients can reject stale asynchronous results. `storage` is
always `read_only`; `difference_definition` is always `b_minus_a`.

| Response status | Meaning |
| --- | --- |
| `ready` | Both source tables are compatible and all eleven nutrient differences are known |
| `partial` | Tables have a compatible measured basis/preparation; one or more nutrient differences are unknown, possibly all |
| `not_comparable` | One source needs attention, preparation differs, measured basis is unknown or mass/volume units differ; no differences are returned |

For each known pair, `difference = b - a`. `lower: a` means A's numeric value is
lower, `lower: b` means B's is lower, and `equal` means exact equality. Lower is
only a numeric direction. It is not a winner, recommendation, nutrition score,
allergy-safety decision or complete regulatory verdict. Unknown pairs have null
differences/directions with explicit reasons. A usable opposite side remains
visible when one historical source is unavailable.

## Transport, readiness and privacy

The endpoint accepts at most **64 KiB of actual request bytes**, including chunked
input, before JSON parsing or source work. Oversized requests return 413. Strict
validation, unknown-field rejection, raw-number precision checks and bounded
redacted 422 errors use the existing shared middleware. Photos, raw OCR and
private account snapshots are outside this contract. Corrected structured package
facts supplied for comparison are not saved as a side effect.

Responses use `Cache-Control: no-store`. CORS follows configured explicit origins;
disallowed origins receive no permission header. Authentication is unnecessary.
`/v1/meta` reports `capabilities.comparison: true` and the comparison version even
without a catalogue, community runtime, reviewed glossary or cloud connection.
Current confirmed inputs still work; historical unavailable states remain explicit.
This adds no paid service, billing requirement, Gemini dependency or training job.

The synthetic [request](../../contracts/examples/comparison-v1.request.synthetic.json)
and [response](../../contracts/examples/comparison-v1.response.synthetic.json)
are integration examples, not real products or scans. The
[release review](../planning/BACKEND_V0_8_0_REVIEW.md) records implementation,
local validation and hosted/publication evidence as separate gates. The current
frontend's existing comparison view does not automatically consume this new route;
source-aware server integration has its own frontend release scope.
