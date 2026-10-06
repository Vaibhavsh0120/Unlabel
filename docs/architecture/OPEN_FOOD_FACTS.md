# Open Food Facts integration plan

Decision: **selected by the user on 5 October 2026**. Backend v0.2.3 implements live product lookup and separate direct-input nutrition lookup/normalization, plus snapshot rich facts. Strict product/catalogue lookup v1 responses remain unchanged. India export acquisition/import now feeds a networkless hosted build with verified SQLite/receipt and separate typed catalogue status/identity/facts lookup. Health/claim analysis and Flutter barcode capture remain planned.

Open Food Facts (OFF) does the primary online product-data heavy lifting: identity, ingredients, nutrition and available computed insights. Python will later apply reviewed FSSAI/ingredient criteria. Current OFF nutrition and user-confirmed label input have separate origin wrappers and are never silently combined. The future review flow preserves differences from the physical package. The MVP is online-first; a second Dart rule engine is not required.

## Planned barcode-to-result workflow

1. The future Flutter scanner reads a barcode or accepts a manually entered code. Keep it as a string, preserving leading zeros. Retain both the captured code and any returned normalized code; verify identity before using a different code.
2. When online lookup is requested, the client sends only the barcode and necessary public lookup options to `GET /v1/products/{barcode}`. Photos, OCR streams, allergy/diet preferences, history and user identifiers are excluded.
3. `backend/app/providers/products/` validates bounded input and queries OFF with a fixed application User-Agent. Use one supported upstream API version and a small field selection; there is no per-frame query or search-as-you-type request.
4. The adapter validates the provider response and returns Unlabel's stable normalized product snapshot. Flutter does not depend on raw OFF schemas.
5. The client can show a basic record-based product view without requiring OCR. Display identity, ingredients, declared allergen/trace information, nutrition and available computed insights with source labels. Missing fields stay unknown; OFF scores are not FSSAI verdicts or allergy-safety evidence.
6. Capture current-package claims and missing/conflicting facts when needed. Differences require review; no silent replacement or merging. User confirmation preserves OFF provenance and separately records package confirmation.
7. The backend evaluates available source-tagged inputs using reviewed criteria. Record-only findings are identified as such; OFF alone cannot establish that a front-label claim matches the current physical package. No result certifies complete legal compliance.
8. An explicitly saved local snapshot keeps its source and date. If OFF fails but the backend is reachable, it can analyze sufficient confirmed package fields. If the backend is unavailable, retain drafts/saved results and defer fresh analysis.

## Provider and client contract

The current [official API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/) recommends the v3 family for new integrations and identifies v3.6 as current. The adapter pins v3.6 and uses synthetic fixtures for its supported shape. Nutrition and tag schemas have changed; see the [provider changelog](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-api-and-product-schema-change-log/) and [verified nutrition research](../research/OFF_NUTRITION_V3_6.md).

OFF's version is independent of Unlabel's `/v1` routes. Provider changes are absorbed by the backend adapter. If an update requires a breaking normalized contract, use Unlabel's existing API compatibility policy rather than assuming installed APKs/IPA builds update with the server.

Each current product/nutrition lookup includes:

- Lookup state: `found`, `not_found`, `rate_limited`, `unavailable` or `incompatible_response`.
- Captured barcode, returned code and product identity when supplied.
- Available normalized fields; the separate nutrition endpoint preserves serving/100 g/100 mL basis and explicit unknowns.
- Provider ID `open_food_facts`, canonical product link and attribution/license metadata.
- Retrieval time and any available provider modification/revision metadata; these are different dates.
- Unlabel adapter/schema/normalization versions where applicable; dates remain available for client freshness policy.
- Source metadata and nutrient row/table references, with warnings for absent, incompatible or conflicting data.

Lookup states are separate from normalization status (`complete`, `partial`, `needs_correction`) and future claim outcomes (`supported`, `contradicted`, `insufficient_information`). A missing database record says nothing about product safety. Community allergen tags, vegetarian inferences and nutritional scores do not replace package declarations or reviewed policy.

## Current narrow nutrition adapter

`GET /v1/products/{barcode}/nutrition` reads `nutrition.input_sets` and accepts direct `value` entries only from `packaging`/`manufacturer` tables. It supports declared per-100 g, per-100 mL and serving bases with supported as-sold/prepared state. Computed sets, estimated-source tables, qualified `<`/`>` values and absent direct values are excluded, with warnings. It does not fall back to old `nutriments` or expose guessed/computed rows as label evidence. Empty accepted tables have unknown cells without a fabricated original row.

The adapter supports energy kcal/kJ, fat, saturated fat, available/total carbohydrates, total/added sugars, fibre, protein, sodium and salt. Canonical energy is kcal; other cells use g. Original direct rows, original/normalized bases, preparation and input table source remain visible. Equivalent duplicates retain row IDs; conflicts require correction. Comparable tables with differing known values produce `provider_tables_disagree` and `needs_correction`, preserving both tables; no rounding tolerance is invented. Total/added sugar, available/total carbohydrates and sodium/salt remain separate. There is no density conversion or unknown serving-size estimate.

At most 16 upstream tables and 64 accepted rows are processed. A table that would exceed the row budget is excluded as a whole with `nutrition_row_budget_exceeded`. Unsupported/sparse data stays unknown/partial; found is not a promise of complete nutrition. A snapshot's `complete` status concerns successful normalization of submitted rows, not complete coverage or a health/legal verdict. OFF lookups remain community-data assessments and use partial completeness.

Direct public feasibility reads on 5 October 2026 fetched schema-1004 nutrition records with four input tables for Nutella `3017620422003` (0.68 seconds) and Coca-Cola `5449000000996` (0.18 seconds). These two samples prove retrievability without a key, not Indian coverage or general performance. The [release review](../planning/BACKEND_V0_2_0_REVIEW.md) records actual endpoint/deployment checks separately.

## Requests, failure and offline behavior

Public product reads do not require a provider API key or account authentication. The backend sends a bounded public application User-Agent identifying Unlabel rather than an individual. Live read feasibility has been checked; no OFF account/form/contribution flow was created. Recheck OFF's current API-use guidance as traffic and scope grow.

The backend proxy gives future Android/iOS/web clients the same adapter behavior and User-Agent. Requests may share upstream outgoing-IP quotas. Current reads have an eight-second default total deadline, 512 KiB default decoded-response budget, six-connection client pool, redirects disabled and no automatic retry/cache. Client deduplication and shared traffic controls are later work. Recheck current limits rather than promising unlimited free reads.

Do not use a writable Vercel SQLite database or instance-local counter as durable storage/global quota enforcement. A bounded in-memory cache is disposable. No cache is necessary for correctness, and a cold instance must still have a safe failure path.

| Condition | Planned behavior |
| --- | --- |
| Product found | Show available source-tagged draft information; verify against the package |
| Product/field missing | Continue label capture/correction; preserve unknown values |
| Rate limit, timeout, server error | Mark lookup unavailable or rate-limited; continue supported analysis |
| Unknown provider schema | Reject affected data; return incompatible response instead of guessed mappings |
| Label differs from OFF | Expose the conflict and retain both origins; confirmed package governs scan evidence |
| Offline, previously saved snapshot | Show it with its date/source/staleness; do not present it as refreshed data |
| Offline, uncached barcode | No new OFF lookup or fresh analysis; offer saved results/local preferences and optionally draft capture |

A future bounded device/browser cache uses code, locale and adapter/schema version as its key. It remains separate from private scan history and the canonical regulatory corpus, with freshness rules and user deletion. Limited offline features are saved reports/snapshots, local preferences and an optional small glossary. Website caching requires its own implementation; saved results do not recompute rules.

## Attribution and ownership

OFF's database uses ODbL, individual contents use the Database Contents License, and images use CC BY-SA. Show appropriate source/link/license attribution wherever OFF data is displayed or reused. Database reuse/export/combination must respect applicable ODbL attribution and share-alike obligations; storing records in separate folders does not itself remove those obligations. See [official license guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/).

Keep OFF snapshots source-separated and read-only. Do not automatically upload user corrections, photos or new products. Contributions would require a separately designed, explicitly authorized write flow. The selected lookup does not require remote product images; do not add image downloads to this foundation. If images are used later, retain their attribution and applicable image rights.

Ownership: backend teammate owns the provider adapter and schema/failure fixtures; Flutter teammate owns barcode capture, conflict review and dated local snapshots; the evidence owner reviews attribution/provenance and source distinctions. Acceptance covers found/missing/conflicting records, nutrition bases, leading-zero barcodes, schema changes, quota failure, offline behavior and stable old-client responses.

The product and narrow nutrition adapters have regression tests and bounded live provider evidence. v0.2.3 adds complete official JSONL acquisition and a separate snapshot facts route. Direct packaging/manufacturer nutrition uses the shared parser; legacy aggregates remain unsupported. Canonical tags expose source availability, optional schema/record dates stay distinct from export age, and selected-front image URLs carry official attribution/license metadata without bundling image bytes. The [current review](../planning/BACKEND_V0_2_3_REVIEW.md) records candidate completion, counts, hashes, field rates and hosted gates. Coverage remains `unverified`; a filtered export does not represent every product sold in India. The earlier [CSV coverage report](../research/CATALOGUE_V0_2_2_COVERAGE.json) and [acquisition history](../research/INDIA_EXPORT_FEASIBILITY.md) remain historical. [Catalogue workflow](CATALOGUE.md).

Manual refresh is every nine calendar months from source export, changed by the user on 6 October. The backend builds the tracked source into an immutable hosted SQLite/receipt and exposes source age; actual hosted packaging/read verification belongs in its review. Existing live product/nutrition routes retain OFF API provenance and are never silently replaced by snapshot data. Catalogue misses make no upstream request. This backend-held database still needs client connectivity and does not prove phone offline capability.
