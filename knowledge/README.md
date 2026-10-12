# Reviewed claim knowledge

Current backend **v0.12.0** loads the unchanged **claims-2026-10-06.1**
seven-claim projection from two canonical JSON files. The separate current
English/Hindi ingredient-function glossary has **six entries** in
[glossary-v2.json](../backend/app/reports/glossary-v2.json), version
`ingredients-2026-10-08.1`, with its own SHA-256/byte/count artifact. It is outside
the two-file FSSAI receipt. Function metadata does not establish health, allergy
or Indian category permission. OFF/research facts and confirmed package rows
retain separate origins. [Current report scope](../docs/architecture/LABEL_REPORT.md).

Historical backend v0.5.0 introduced the three-entry
[glossary-v1.json](../backend/app/reports/glossary-v1.json); v0.9.0 expanded to the
six-entry projection now retained by v0.12.0. Both versions and their dated
reviews remain preserved. No empty ingredient/allergen/translation scaffolding
is required for those implemented files.

| Canonical file | Current content |
| --- | --- |
| [rules/claims/reviewed-v1.json](rules/claims/reviewed-v1.json) | Seven numerical fibre, sugar and sodium claims with applicability, alternatives, evidence locators and bounded wording |
| [sources/registry/fssai-claims-v1.json](sources/registry/fssai-claims-v1.json) | Three reviewed official source metadata records, PDF hashes/sizes/pages, known dates, review status and qualifications |

The reviewed source date is **6 October 2026**; v0.3.0 was independently released on **7 October 2026**; released v0.4.0 and v0.5.0 retain its knowledge unchanged in Asia/Calcutta. Review dates are not publication or effective dates. A known future publication/effective date, future or non-current review, superseded source or unsuitable category suppresses the affected numerical assessment. Unknown dates stay null; they are never replaced with retrieval dates.

[Current six-entry source review](../docs/research/INGREDIENT_GLOSSARY_V0_9_0.md) ·
[Historical three-entry source review](../docs/research/INGREDIENT_GLOSSARY_V0_5_0.md).

## Reviewed sources

| ID | Official source | Acquired PDF bytes | SHA-256 |
| --- | --- | --- | --- |
| `fssai-ac-2022-schedule-i` | [2022 Advertising and Claims Gazette amendment](https://fssai.gov.in/docs/food-law/regulations/amendments/advertising-claims/Gazette_Notification_Amendment_14_12_2022.pdf) | 1,654,559 | `9e516f3fa689955ecd3eda3f4f9c07511d89b68a4272bfebc277cbb10be6da72` |
| `fssai-ac-2018-general` | [2018 principal Gazette regulations](https://fssai.gov.in/docs/food-law/regulations/Gazette_Notification_Advertising_Claims_27_11_2018.pdf) | 1,178,339 | `58184c716ad254e2ec698e3c4d212dfaacea4bf43cc09dcd48daeb590e94d9f4` |
| `fssai-ac-compendium-v4` | [Advertising and Claims compendium, Version IV](https://www.fssai.gov.in/upload/uploadfiles/files/Compendium_Advertising_Claims_Regulations_14_12_2022.pdf) | 787,091 | `4bfe17ba6fe59a3a8ffc7326ad723014b19d69b68cebffdc68717cdfff5cb191` |

These hashes record the acquired source PDFs used for review; the PDFs are not committed or shipped in the function. The repository packages reviewed threshold facts and source metadata only. The Gazette is authoritative; the compendium is a reference cross-check. The [official amendment index](https://fssai.gov.in/food-law/regulations/amendments/advertising-claims) was reviewed for this version. [Dated byte/hash verification](../docs/research/FSSAI_CLAIMS_V0_3_0_SOURCE_CHECK.json) matches all three registry records. Complete Legal Metrology or FSSAI certification is outside scope.

Fibre criteria cite Schedule I **row 14, Gazette PDF page 13**; sugar cites **row 10, page 12**; sodium cites **row 13, page 13**. Energy alternatives cite **Schedule I Note 2, page 13** and use **4.2 kJ per kcal** from original selected confirmed rows. The existing normalization-v1 snapshot preserves its separate 4.184 conversion. The API exposes claim-specific conversion version `fssai-schedule-i-note2-v1`.

## Scope and packaging

The engine checks `source_of_fibre`, `high_fibre`, `low_sugar`, `sugar_free`, `low_sodium`, `very_low_sodium` and `sodium_free` for confirmed ordinary general foods with matching selected table, form and preparation. It accepts only strict structured rows and identified claims. One applicable fibre alternative may support the numerical criterion; contradiction requires all applicable alternatives to be known and fail. Missing, conflicting or unsuitable evidence stays `insufficient_information`.

`high_protein`, `source_of_protein`, `no_added_sugar` and `multigrain` are recognized but unreviewed, and always return `insufficient_information`. The engine does not derive manufacturing non-addition from total sugar, judge ingredient safety, score health or certify full legal compliance. [Current API/criteria](../backend/README.md).

`backend/build_catalogue.py` validates and packages only the two approved JSON files under ignored `backend/app/claims/data/`, alongside a strict hash/length receipt. It copies no source PDF, scan, arbitrary file or credential and makes no network request. Its successful stdout contains `catalogue`, `claims_knowledge` and the separate `research_catalogue` receipts. With `VERCEL=1`, startup requires a valid receipt even for an explicit knowledge-directory override. Missing/damaged knowledge disables claim/rule/evidence routes without disabling health, live OFF or catalogue routes. A verified receipt is summarized by `/v1/meta.knowledge_artifact`; direct local canonical-source loading has no artifact receipt. [Build/run guide](../docs/planning/LOCAL_DEVELOPMENT.md).

Broader ingredient aliases, educational nutrient classifications, allergen
mappings and reviewed bilingual report templates remain future content. They
are not implemented merely by a reserved directory. The retained
`sources/downloads/` location is for ignored permitted local reference files;
source PDFs are not shipped in the backend bundle.

Use exact identifiers and reviewed rules first. A future small ingredient corpus can use structured lookup or SQLite full-text search; semantic/vector RAG is not required. Read the [evidence strategy](../docs/research/EVIDENCE_STRATEGY.md) before copying source content. Free-to-read does not automatically grant redistribution rights.
