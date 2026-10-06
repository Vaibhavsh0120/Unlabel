# Backend v0.2.1

OFF's official bulk export is now verified and processed locally. An India identity catalogue can be built in bounded SQLite storage, with exact barcode lookup, export provenance and atomic manual replacement. Frontend remains **0.0.0+1**; no APK/IPA workflow is dispatched.

## Added

- Official global CSV/TSV streaming acquisition with exact India selection, finite byte limits, gzip EOF/checksum evidence and exclusive publication.
- Plain/gzip JSONL importer, indexed read-only SQLite store, validated manifest, bounded unknown-preserving product fields, strict duplicates and failed-import preservation.
- Separate optional `GET /v1/catalogue/products/{barcode}` plus capability/status metadata. Existing live product/nutrition contracts remain unchanged.
- Accurate shared redacted 422 OpenAPI/schema, including numeric middleware responses.
- Current contracts/examples, storage comparison, measured acquisition report, completed baseline docs/files review and version plan.

## Measured source and limits

The 5 October export was streamed completely on 6 October: 1,275,171,186 compressed bytes; 4,535,553 source rows; 21,188 India rows. The 11,993,088-byte SQLite index contains 21,138 supported barcodes; 50 unsupported codes are counted. Ingredients are missing for 15,780 records. Live India's 24,706 count differs; coverage remains independently unverified. Catalogue nutrition, images and record modification dates are excluded; legacy incomplete allergen fields stay unknown.

Catalogue data is local/ignored, not packaged in the Vercel Git deployment. Production retains live OFF lookup; the optional catalogue reports inactive until a verified artifact is configured. v0.2.2 will address coverage/richer fields and reproducible free distribution, followed by reviewed FSSAI work. The user's latest replacement policy is **every nine months**, manually staged/validated/swapped; no automatic job was scheduled.

[Validation and review](BACKEND_V0_2_1_REVIEW.md) · [Catalogue workflow](../architecture/CATALOGUE.md) · [Source research](../research/INDIA_EXPORT_FEASIBILITY.md).
