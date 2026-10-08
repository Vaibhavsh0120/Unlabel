# Frontend v0.5.0+6: researched product information

Implementation in progress on `main`, 8 October 2026. Push and hosted verification
remain pending until the checks below are closed.

Search includes sourced website records alongside existing OFF catalogue results.
Research entries use immutable entry IDs, including records without a barcode.
Opening one shows its ingredients, contains/may-contain declarations, nutrition
basis, source URL/date, identity uncertainty and recorded conflicts. Additional
website tables retain their unconfirmed status. They never masquerade as a
user-confirmed package report.

Both result sources load independently, with separate scoped pagination. A failed
source leaves usable results visible. Exhausted pages are not restarted. Stale
requests cannot overwrite a newer query. Existing report photo requests remain
bounded, and researched details use their own bounded public cache. An older
backend without the capability keeps the established catalogue workflow.

The botanical design, four-tab order, existing Scan Label and Profile layout are
preserved. Research browsing introduces no login, cloud writes, new dependency,
paid service or fabricated barcode. Comparison/claims keep their existing
confirmed-source requirements.

## Verification

Analyzer clean; **193 tests pass**, including all243 acquired observations. Final
release web build and rendered checks are pending. Meaningful
model/repository/widget tests cover malformed sources, null barcodes, frozen
observations, qualifiers, mixed source failures, cursor exhaustion, stale requests
and readable small/large screens. Physical-device proof is separate.

Final review replaced internal warning codes with understandable qualifications
and exposed useful variant/import context in result rows. Unknown warning codes
receive generic explanatory copy. The next automatic scan/results redesign is
tracked separately in [its plan](AUTOMATIC_SCAN_PLAN.md).

See [accepted plan](POPULAR_PRODUCTS_DATABASE_PLAN.md),
[backend review](BACKEND_V0_10_0_REVIEW.md) and
[source product list](../research/POPULAR_PRODUCTS_ADDED.md).
