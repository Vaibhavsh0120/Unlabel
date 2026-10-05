# Canonical knowledge — no corpus populated yet

This area will hold small, reviewed JSON/CSV records rather than a scraped website or trained model. They are the canonical input to the backend's reviewed rule/evidence bundle and an optional small Flutter ingredient glossary. Open Food Facts supplies primary online product data separately. Optional local SQLite indexes are derived, not durable Vercel storage. Those exports will be created later by tools in scripts.

| Folder | Future content |
| --- | --- |
| sources/registry | Publisher, URL, version, provision, dates, review state and reuse rights |
| sources/downloads | Ignored local source files, only when permitted and needed |
| ingredients | Canonical names, INS/E-number aliases, purpose, uncertainty and evidence IDs |
| rules/claims | Reviewed claim criteria and applicability, including required fields |
| rules/nutrition | Unit/basis criteria and distinct educational versus regulatory references |
| rules/allergens | Declared/may-contain aliases and uncertainty rules |
| translations/en, hi | Reviewed glossary and result templates; preserve allergen names and numbers |

Every active finding must trace to its input origin (OFF record or confirmed package field) and a reviewed rule/source. Publication date is not necessarily effective date. No legal threshold or claim rule is active in this foundation. Backend fixtures test missing information, applicability and source conflicts; no second device rule engine is required for the MVP.

Use exact identifiers and aliases first. Evidence-passage retrieval can later use SQLite full-text search; semantic/vector RAG is not needed for the initial small corpus. If later added, it retrieves text only and does not replace deterministic criteria.

Free-to-read does not imply permission to redistribute a document. Read the [evidence strategy](../docs/research/EVIDENCE_STRATEGY.md) before copying source content. Community product records from Open Food Facts remain separately identified enrichment, not regulatory evidence.
