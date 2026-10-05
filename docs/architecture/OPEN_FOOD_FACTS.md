# Open Food Facts integration plan

Decision: **selected by the user on 5 October 2026**. This is foundation planning; no barcode plugin, provider adapter, cache or endpoint is implemented yet.

Open Food Facts (OFF) does the primary online product-data heavy lifting: identity, ingredients, nutrition and available computed insights. Python applies reviewed FSSAI/ingredient criteria. The physical package takes priority when confirmed facts differ from a community record. The MVP is online-first; a second Dart rule engine is not required.

## Barcode-to-result workflow

1. The future Flutter scanner reads a barcode or accepts a manually entered code. Keep it as a string, preserving leading zeros. Retain both the captured code and any returned normalized code; verify identity before using a different code.
2. When online lookup is requested, the client sends only the barcode and necessary public lookup options to `GET /v1/products/{barcode}`. Photos, OCR streams, allergy/diet preferences, history and user identifiers are excluded.
3. `backend/app/providers/products/` validates bounded input and queries OFF with a fixed application User-Agent. Use one supported upstream API version and a small field selection; there is no per-frame query or search-as-you-type request.
4. The adapter validates the provider response and returns Unlabel's stable normalized product snapshot. Flutter does not depend on raw OFF schemas.
5. The client can show a basic record-based product view without requiring OCR. Display identity, ingredients, declared allergen/trace information, nutrition and available computed insights with source labels. Missing fields stay unknown; OFF scores are not FSSAI verdicts or allergy-safety evidence.
6. Capture current-package claims and missing/conflicting facts when needed. Differences require review; no silent replacement or merging. User confirmation preserves OFF provenance and separately records package confirmation.
7. The backend evaluates available source-tagged inputs using reviewed criteria. Record-only findings are identified as such; OFF alone cannot establish that a front-label claim matches the current physical package. No result certifies complete legal compliance.
8. An explicitly saved local snapshot keeps its source and date. If OFF fails but the backend is reachable, it can analyze sufficient confirmed package fields. If the backend is unavailable, retain drafts/saved results and defer fresh analysis.

## Provider and client contract

The current [official API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/) recommends the v3 family for new integrations and identifies v3.6 as current. Recheck and pin the supported response schema with fixtures before implementation. Nutrition and tag schemas have changed; see the [provider changelog](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-api-and-product-schema-change-log/).

OFF's version is independent of Unlabel's `/v1` routes. Provider changes are absorbed by the backend adapter. If an update requires a breaking normalized contract, use Unlabel's existing API compatibility policy rather than assuming installed APKs/IPA builds update with the server.

Each proposed snapshot includes:

- Lookup state: `found`, `not_found`, `rate_limited`, `unavailable` or `incompatible_response`.
- Captured barcode, returned code and product identity when supplied.
- Available normalized fields with units, serving/100 g/100 mL basis and explicit unknowns.
- Provider ID `open_food_facts`, canonical product link and attribution/license metadata.
- Retrieval time and any available provider modification/revision metadata; these are different dates.
- Unlabel adapter/schema version and freshness state.
- Per-field provenance and warnings for absent, incompatible or conflicting data.

Lookup states are separate from analysis outcomes (`supported`, `contradicted`, `insufficient_information`). A missing database record says nothing about a product's safety. Community allergen tags, vegetarian inferences and nutritional scores do not replace package declarations or reviewed policy.

## Requests, failure and offline behavior

Production product reads do not require a provider API key or account authentication. Send the documented application identity; identify Unlabel rather than an individual user. Follow OFF's API-use onboarding guidance before live integration. This foundation creates no account, submits no form and makes no product-data request.

The backend proxy gives Android, iOS and web the same adapter behavior and User-Agent. It also means requests can share upstream outgoing-IP quotas. Bound request volume, response sizes, concurrency, timeouts and retries; deduplicate repeated barcode lookups, respect rate-limit/backoff guidance, and stop retries after a small limit. Recheck current limits before deployment instead of promising unlimited free reads.

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

The architecture is selected; actual API behavior, integration, Indian-product coverage and offline cache behavior remain to be validated during implementation.
