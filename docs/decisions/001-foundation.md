# Decision 001: a local, evidence-first planning foundation

Date: 5 October 2026. Historical initial decision. Client/deployment assumptions and the folder-only boundary are superseded by [Decision 002](002-platforms-offline-release.md).

## Context

Unlabel is a college mini-project with four food-label features and a strict ₹0/no-card requirement. The user requested only folder structure and complete architecture/data workflows. The attached compliance-project screenshot provides context, not an instruction to certify all packaged goods.

## Decisions

1. Keep frontend, backend, canonical knowledge, contracts, synthetic fixtures, scripts and docs in one repository.
2. Recommend Flutter, Android first, with on-device bundled ML Kit OCR. Validate the Flutter adapter and device camera formats later.
3. Use Python/FastAPI for the backend. The user explicitly selected this after considering Rust. Rust/Axum remains a viable alternate, documented in [backend options](../research/BACKEND_OPTIONS.md).
4. Use reviewed canonical ingredient/rule/source files; derive local SQLite and mobile glossary exports. Start with exact/alias matching, with optional FTS evidence retrieval later.
5. Keep nutrition/claim evaluation deterministic and versioned. Gemini only explains existing findings and remains optional.
6. Run the backend on an existing laptop/private network. No hosting account, cloud database, paid trial or store account is required for the Android demo.
7. Keep preferences/history on the phone. The backend issues neutral suitability facts/reasons; the phone applies local selections without duplicating regulatory evaluation.
8. Preserve original/corrected label text, nutrient bases and unknown states. Every finding has input and source provenance.
9. Create folders/docs/ignore rules/settings examples only. Do not create product entry points, package manifests, source seeds, credentials or deployments in this phase.

## Consequences

The no-Gemini backend can deliver the planned full baseline. A missing backend has explicit partial behavior. The team must curate a small source/rule set and validate physical-device OCR; free APIs alone do not prove label accuracy.

No vector RAG, custom model training, microservices or paid infrastructure is required. Provider models/quotas and regulations must be rechecked before code uses them. Licensing and current effective dates are part of evidence review.
