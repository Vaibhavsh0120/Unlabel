# Frontend v0.5.0+6: researched product information

Implementation verified locally on `main`, 8 October 2026. Source
`00ae175993aa1cf435c3ff9ec9c8ee05cef94005` is independently pushed, with observed
READY deployment `dpl_AscVhThAEqDPsd3E1REiFbpMLbPB`. Its exact-source read-only
verification passed 49 checks, including all 21 OCR asset hashes. See the
[production receipt](../research/FRONTEND_V0_5_0_PRODUCTION.json). Later local
v0.6.0 changes do not replace this identity or inherit its hosted proof.

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

Analyzer clean; **194 tests pass**, including all 243 acquired observations.
The production-target release web build passes. Meaningful
model/repository/widget tests cover malformed sources, null barcodes, frozen
observations, qualifiers, mixed source failures, cursor exhaustion, stale requests
and readable small/large screens. Physical-device proof is separate.

Playwright CLI reviewed real mixed-source search, unknown-data retailer details,
manufacturer ingredient/nutrition details, copy-source feedback, expandable notes
and the retained back-to-search path against the READY backend v0.10.0. Light-theme
search, manufacturer details and expanded notes were captured and visually
reviewed at 390, 1440 and 1728 px. The browser uses the supported debug loopback
production preview proxy; the separate release build targets the canonical HTTPS
API. This does not establish a frontend production deployment or native behavior.
See the [render evidence](../research/FRONTEND_V0_5_0_RENDER.json).

Rendered review found that Flutter web exposed `SelectableText` declarations as
empty disabled textareas. Explicit static semantics now make the complete
ingredients, unknown declarations, source URL and source notes readable while
preserving pointer selection. The targeted accessibility regression and final
browser snapshot verify the repair.

Better Design review and comprehension checks are recorded in the render
evidence. Raw spacing checks included Flutter's intentionally offscreen live
announcements and the final partially visible card in a scrolling list. Their
dispositions are explicit; the final product-layout measurement excludes only
the screen-reader-only announcement tags and reports no findings at all three
widths. The screenshot review establishes visible layout separately. A new
dark-theme visual recheck is not included in this checkpoint's receipt.

Final review replaced internal warning codes with understandable qualifications
and exposed useful variant/import context in result rows. Unknown warning codes
receive generic explanatory copy. The next automatic scan/results redesign is
tracked separately in [its plan](AUTOMATIC_SCAN_PLAN.md).

See [accepted plan](POPULAR_PRODUCTS_DATABASE_PLAN.md),
[backend review](BACKEND_V0_10_0_REVIEW.md) and
[source product list](../research/POPULAR_PRODUCTS_ADDED.md).
