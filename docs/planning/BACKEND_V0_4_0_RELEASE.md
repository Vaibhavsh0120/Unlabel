# Backend v0.4.0: Community Product Catalogue

Goal: each corrected public package observation can improve future exact-product
lookups, with its original evidence and conflicts visible.

Four new routes provide automatic bounded observation saving, private retry
receipts, qualified exact-barcode candidates/reviewed facts and a resolved field
view. Compatible missing fields complement one another; contradictory facts
remain unresolved. Provisional observations stay staged. Repeated semantic facts
are deduplicated without treating repetition as proof of accuracy.

The **Unlabel** Firebase project uses the first Standard **unlabel** database
with free quota and no billing account. Anonymous write authentication runs
behind the scenes; direct client database access is denied. No paid storage,
Functions or AI service is needed. Local secrets are recoverable through
authenticated `.env.age` encryption.

This is a backend/source release. Flutter remains **0.0.0+1**; capture/OCR, client
pairing/correction and automatic save integration are still pending. Nutrition
and claim rules retain their existing evidence boundaries. A full label report
is the next separate version; no universal health score is introduced here.

Publication is pending the final push and exact hosted verification.
[Validation and remaining gates](BACKEND_V0_4_0_REVIEW.md) ·
[Client contract guide](../../contracts/README.md) · [Complete plan](MASTER_PLAN.md).