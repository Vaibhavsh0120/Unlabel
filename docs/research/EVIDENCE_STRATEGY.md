# Evidence strategy

Status: local **v0.4.0** implements automatic structured observations, private
staging and qualified source resolution; production remains v0.3.0 until
push/hosted verification. The seven reviewed numerical claims and three source
records are unchanged. Firebase Unlabel is configured on free Standard database
`unlabel` without linked billing. Product observations remain distinct from rule
evidence; review never confirms the caller's current packet or activates new
criteria. [Master plan](../planning/MASTER_PLAN.md).


The [Indian food coverage strategy](INDIAN_FOOD_COVERAGE.md) records the user's
barcode/back-image/front-image goal, measured product gaps, source selection,
language limits and proposed acquisition/implementation sequence. Generic food
composition stays separate from packaged-product and confirmed-label facts.
Source research began 5 October; the selected claim scope was reviewed 6 October
2026 and fresh byte/hash checks passed on 7 October (Asia/Calcutta).
[Actual source register/hashes](../../knowledge/README.md) ·
[Current gates](../planning/BACKEND_V0_4_0_REVIEW.md) ·
[Community/source boundaries](../architecture/COMMUNITY_CATALOGUE.md).

## Decision

Unlabel should begin with manually reviewed ingredient records, aliases, and
versioned rules. Use structured lookup to select relevant facts and provisions.
Do not make a regulator API, vector database, or live document scraper a scan
dependency. A small local corpus is practical for a college mini-project.

Retrieval can later use SQLite FTS5 to find reviewed evidence paragraphs.
That would support grounded explanations without requiring embeddings.
Numeric decisions belong to explicit reviewed rules, not an AI answer.
Semantic retrieval is a future option if corpus size and measured retrieval
quality demonstrate a need; it is not required for the first implementation.

## Canonical folders

```text
knowledge/
  sources/
    registry/             # Source metadata and review records
    downloads/            # Ignored local copies, only when reuse permits
  ingredients/            # Reviewed ingredient identities, purposes, aliases
  rules/
    claims/               # Reviewed checks for supported claim types
    nutrition/            # Units, normalization, and reviewed interpretations
    allergens/            # Reviewed aliases and declared/possible evidence
  translations/
    en/                   # Reviewed plain-English explanation records
    hi/                   # Reviewed Hindi explanation records
```

The claim-rule and three-source registry JSON are populated; the combined build validates and packages exactly these two files with a receipt. Other folders remain ownership boundaries for later implementation. Placeholders do not establish an active rule, licensed dataset or completed glossary.
Regulator evidence and third-party product records must remain separate.

## Official source register

The following references were checked during architecture research. A URL is
a discovery/reference entry, not permission to reproduce an entire document.

| ID | Official reference | Observed version and access | Planned purpose |
| --- | --- | --- | --- |
| FSSAI-LD-INDEX | [Labelling & Display amendment registry](https://fssai.gov.in/food-law/regulations/amendments/labelling-display) | Search-indexed registry lists amendments dated 8 August 2025 and 24 March 2026; direct fetch was inconsistent | Discover newer notifications and effective dates |
| FSSAI-LD-VII | [Labelling & Display compendium, Version VII](https://fssai.gov.in/upload/uploadfiles/files/Comp_Labelling%20Display_Version%20VII_03042025.pdf) | PDF readable; Version VII, 3 April 2025 | Reference structure for label fields, nutrition bases, exemptions, declarations |
| FSSAI-LD-VIII | [Labelling & Display compendium, Version VIII](https://stg-old.fssai.gov.in/upload/uploadfiles/files/Comp_Labelling%20Display_Version%20VIII_09_09_2025.pdf) | Official search result identifies Version VIII, 9 September 2025; PDF fetch timed out | Candidate newer reference requiring full review |
| FSSAI-CLAIMS-IV | [Advertising & Claims compendium](https://www.fssai.gov.in/upload/uploadfiles/files/Compendium_Advertising_Claims_Regulations_14_12_2022.pdf) | Version IV cross-checked against authoritative Gazette and amendment index for the selected seven-rule scope on 6 October; fresh hash check matches registry | Reference cross-check, not the legal authority or complete compliance proof |
| FSSAI-REG-INDEX | [Official regulations index](https://stg-old.fssai.gov.in/cms/food-safety-and-standards-regulations.php) | Indexed official content explains compendium limitations | Discover original regulations, amendments, and corrigenda |
| LM-INDEX | [Department of Consumer Affairs Legal Metrology index](https://consumeraffairs.gov.in/pages/legal-metrology-act) | Official index found; direct fetch failed during research | Future packaged-declaration scope research |
| LM-TIMELINE | [PIB Legal Metrology labelling announcement](https://www.pib.gov.in/PressReleaseIframePage.aspx?PRID=2097258&lang=2&reg=48) | Readable official release, 29 January 2025 | Amendment timing and declaration scope context |
| NIN-DGI-2024 | [ICMR-NIN Dietary Guidelines for Indians 2024](https://www.nin.res.in/dietaryguidelines/pdfjs/locale/DGI24thJune2024fin.pdf) | Official PDF front matter readable/indexed; rights restriction identified | Reference-only context pending reuse review |

The amendment registry is newer than the readable labelling compendium.
Do not label the readable PDF as the complete current law.
No 2026 amendment provision or effective date was activated in this foundation.
Notification dates and dates when provisions become applicable must be reviewed
separately; the most recently published text may contain future requirements.

FSSAI describes compendia as reference aids rather than legal documents.
Original notifications and amendments prevail where a compendium differs.
An executable rule must therefore identify its underlying authoritative
provision, amendments, exceptions, and applicable dates.

No suitable public FSSAI product/ingredient lookup API was established by this
research. Do not infer that one exists from the availability of regulator PDFs.
The plan uses official publications as evidence, with manual curation.

The attached project-context image refers to packaged commodities and Legal
Metrology. Reserve that extension in the roadmap. Do not add a Legal Metrology
module now or describe Unlabel as an official compliance certification service.

## Source metadata contract

The current claim registry captures the relevant source IDs, official URLs, acquired PDF hashes/sizes/pages, known dates, reviewed status and qualifications. Future expanded registry records should capture:

- Stable source ID, publisher, jurisdiction, title, and original official URL.
- Document type: notification, amendment, corrigendum, compendium, or guidance.
- Version, publication/notification date, and effective date where established.
- Provision/section and page reference used for each derived rule or fact.
- Access state: fully reviewed, metadata-only, fetch failed, or superseded.
- Date retrieved, date reviewed, reviewer, and next review trigger.
- Reuse/license terms, attribution needs, and whether local storage is allowed.
- Acquired checksum/byte count when reviewed source content is fetched; full PDFs remain outside the tracked/runtime bundle.
- Superseded source IDs, exceptions, and unresolved interpretation questions.

Keep unknown dates and permissions explicitly unknown. Do not substitute the
retrieval date for the document version or its effective date.
Do not store full documents in Git by default.

The ICMR-NIN 2024 publication is free to read, but its front matter requires
prior written permission for electronic storage/reproduction to create a
product. Keep a reference link and rights-review record; do not automatically
mirror it into downloads, a bundled corpus, or a retrieval index.
Review reuse conditions individually for every other source as well.

## Ingredient and rule curation

Ingredient records should identify names, aliases, INS identifiers where
verified, technological purpose, relevant evidence, and uncertainty.
An unfamiliar chemical name alone does not establish danger.
Do not infer additive quantities or laboratory safety from ingredient presence.

Claim records should specify the claim being checked, required observations,
units/basis, allowed input states, applicable rule version, and evidence links.
Seven numerical fibre/sugar/sodium claim criteria are active for confirmed ordinary general foods with matching selected-table context. High/source protein, no added sugar and multigrain remain unreviewed and insufficient; wider criteria need their own source/applicability review.
For example, total sugar alone cannot establish whether sugar was added.
Some claim conditions require manufacturing information absent from a label.

Allergen evidence should distinguish a declared ingredient, an explicit
"contains" statement, a precautionary "may contain" statement, and unknown
information. Ingredient aliases require review before matching.
Vegetarian preference evidence must remain separate from allergen evidence.
Missing OCR text cannot prove absence of an allergen or a required declaration.

Reviewed translations should preserve the original fact, units, uncertainty,
and evidence reference. Hindi and English explanations must not strengthen a
claim beyond its source. Any future AI wording requires the same checks.

## Selected Open Food Facts product lookup

Open Food Facts is implemented as the read-only product adapter under
`backend/app/providers/products/`. Camera-confirmed text remains primary.
Do not merge community product records into the regulatory evidence corpus.

The [integration plan](../architecture/OPEN_FOOD_FACTS.md) records barcode-to-backend lookup, provider normalization, source/revision metadata, offline snapshots and failure behavior. Current official documentation recommends the v3 family for new integrations; freeze and test its supported schema before implementation. Unlabel's own `/v1` API is independent of the upstream API version.

[Open Food Facts API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/)
was checked directly and through Context7 on 2026-10-05. Reads do not require
account authentication but require application identity via a custom User-Agent.
The service applies quotas that can change; design a small cache, timeouts,
backoff, and graceful missing-product/unavailable responses.
Do not promise unlimited access or fixed quota availability.

Its database uses ODbL, individual contents use the Database Contents License,
and product images use CC BY-SA. Preserve attribution and review reuse terms
before storing or redistributing records. See its
[license guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side).
Community records may be inaccurate or incomplete; preserve their source and
retrieval time, and expose conflicts for confirmation rather than silently
overwriting the scanned label. No user photo upload is needed for enrichment.

## Review lifecycle and safe outputs

1. Register a source and establish access/reuse status.
2. Review the authoritative provision and amendments in full.
3. Extract a bounded fact or rule with traceable references and exceptions.
4. Review aliases and translations, then approve the record for use.
5. Validate future rules with clear, ambiguous, missing, and conflicting inputs.
6. Revisit the source before implementing a rule, presenting the project,
   or changing corpus versions; record the review date and findings.
7. Mark affected records stale/superseded after an amendment or source conflict.

The result contract should support `supported`, `contradicted`, and
`insufficient_information`, with observed text and evidence references.
An unreadable or incomplete scan should request confirmation or another image.
AI explanations cannot upgrade an unknown outcome into a confident verdict.
Never describe an incomplete ingredient scan as "allergy safe".
These requirements apply to the implemented numerical claim subset and later broader analysis. Any applicable fibre alternative may support a numerical criterion; contradiction requires all applicable alternatives known and failing. Known future source dates or conflicting regulatory energy values suppress affected assessments. Statutory energy uses 4.2 kJ/kcal from original confirmed rows, separately from normalization-v1 4.184. The API identifies numerical-only scope and performs no live regulator lookup or PDF redistribution.
