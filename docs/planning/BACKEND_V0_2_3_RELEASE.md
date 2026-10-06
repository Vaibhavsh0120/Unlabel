# Backend v0.2.3 — rich snapshot product facts

Goal: a future product-detail screen can retrieve dated public product facts from the backend-held India catalogue. This source-only backend version adds `GET /v1/catalogue/products/{barcode}/facts` while preserving the earlier identity, live nutrition, confirmed-input and catalogue-status contracts. Flutter remains **0.0.0+1**.

## Delivered contract

- Exact snapshot identity and manifest, with a separate typed `details` model.
- Availability-aware category, label, allergen and trace tags. A present empty list differs from a missing/invalid source field; neither proves allergy safety.
- Optional provider schema version and record-modification time, distinct from export/build/request dates.
- Direct packaging/manufacturer nutrition tables using the shared bounded parser and normalizer. `missing`, `legacy_unsupported` and `invalid` stay distinct from available direct tables. Legacy aggregate nutrients are not presented as package evidence.
- Optional official selected-front image URL, language, revision, size and attribution/license metadata. No image upload, proxy, download or bundled photo bytes.
- Additive `catalogue_facts` capability, facts schema and synthetic integration example. An older identity-only SQLite catalogue remains readable through its existing routes but cannot enable this capability.

Lookups make no OFF request or automatic live fallback. Sparse facts retain unknowns and warnings; community facts remain separate from confirmed physical-package inputs. Claims, health scoring, comparison, glossary and AI remain disabled in this version.

## Source and verification

The complete official JSONL gzip was acquired with validated EOF on 6 October: **13,084,464,175 compressed bytes**, **83,007,975,584 decoded bytes** and **4,795,607 source records**. The compact India projection has **24,695 rows**, **24,641 supported unique barcodes**, **54 unsupported codes** and **0 duplicates**; its gzip is **2,098,225 bytes**, decoding to **15,084,130 bytes**. No world dump or photo bytes were retained. Source date **2026-10-06T06:53:46Z** sets refresh due **2027-07-06T06:53:46Z**. [Hashes and raw-field measurements](BACKEND_V0_2_3_REVIEW.md).

All **24,641 supported fact records** passed strict validation. **4,657** have direct nutrition tables and **4,519** contain at least one reported direct nutrient; **15,486** remain legacy-unsupported, **4,050** missing and **448** invalid. Official image descriptors exist for **18,682** records; all supported records have a validated modification date. The generated local SQLite is **62,472,192 bytes (59.58 MiB)** with a verified receipt. [Full indexed-field counts and local hashes](../research/CATALOGUE_V0_2_3_COVERAGE.json).

Local v0.2.3 suite: **402 passed**; scoped lint/format (**39 files**) and dependency checks pass. Independent review found no actionable correctness/security issues or demonstrably dead v0.2.3 code; **103 reviewer tests** and Ruff pass. Public application identity and encrypted env were refreshed, with zero tracked private-key markers. Actual private-key decrypt/recovery was not rerun in this continuation. **Pending:** actual hosted facts/receipt verification and publication. Image descriptor validation is separate from remote image availability. [Current review and remaining gates](BACKEND_V0_2_3_REVIEW.md).

Coverage remains `unverified`; India-tagged OFF records do not represent every food sold in India. Nine-calendar-month replacement uses the actual source export date, not rebuild time. The prior [v0.2.2 review](BACKEND_V0_2_2_REVIEW.md) describes its earlier CSV projection and deployment only.

## Release order

Review, document and push v0.2.3 independently, verify its exact deployed source and APIs, then publish the source-only backend prerelease. **Pending:** implementation commit, deployment IDs and tag/release publication. No mobile workflow or existing APK/IPA/tag is changed.

Next, **v0.3.0** adds a small reviewed confirmed-label claim subset with numeric input references, applicability, rule/source versions and explicit insufficient-information outcomes. It does not depend on Gemini. Wider reports, ingredients, suitability and comparison remain later slices. [Two-version plan](../superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md) · [20-group tracker](FEATURE_TRACKER.md).
