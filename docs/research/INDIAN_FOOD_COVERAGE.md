# Indian food coverage: barcode, back label and front package

Research updated **7 October 2026 (Asia/Calcutta)**. Released **v0.4.0 Community
Product Catalogue** is implemented with automatic observations, semantic dedup,
private provisional staging, qualified candidates and typed sourced fields.
Firebase Unlabel's free first Standard database `unlabel` is configured with no
billing. Production **0.4.0** is independently hosted-verified and released; Flutter
**0.0.0+1** still needs capture/OCR/integration. Search/source acquisition and
regional benchmarks remain proposals. No Indian-market coverage percentage or
photo recognition is proved. [Master plan](../planning/MASTER_PLAN.md).

## User goal and scope

Cover as many Indian foods as practical through barcode, back-package image
and front-package image. Prioritize Indian packaged foods, regional brands and
imports sold in India. A product missing from the catalogue must still be
eligible for analysis from sufficient confirmed package information.

Raw ingredients and prepared dishes are a separate possible reference feature.
An image of a dish, a recipe name or a generic composition record does not
establish the ingredients, quantities or nutrition of a particular packet.
The concept-screen scores and sample products remain illustrative.

## Verified baseline

The existing full OFF export was already acquired and validated. Reuse its
tracked India projection; another world-export download is not required for
this plan. The [dated coverage report](CATALOGUE_V0_2_3_COVERAGE.json) records:

| Measurement | Count | Interpretation |
| --- | ---: | --- |
| Indexed supported barcodes | 24,641 | Exact `en:india` records in the dated export; not all foods sold in India |
| Direct nutrition tables | 4,657 | Tables accepted by the current direct-source policy |
| Products with at least one direct nutrient value | 4,519 | 18.3% of indexed records; does not mean complete nutrition |
| Legacy aggregate nutrition excluded | 15,486 | Deliberately unavailable; retain the current source policy |
| Nutrition missing / invalid | 4,050 / 448 | Unknown values, not zero |
| Selected-front image descriptors | 18,682 | Validated official references; remote image availability is not proved |
| Category / label fields available | 13,116 / 9,301 | Provider metadata, not confirmed current-package evidence |

The acquisition report also records **18,129 missing ingredient texts among
24,695 raw India-tagged rows**. That metric has a different denominator from
the indexed counts. Empty available allergen tags cannot establish absence.
There is no verified denominator for the entire Indian retail food market.

Current capabilities are defined by the [API plan](../architecture/API_PLAN.md)
and [feature tracker](../planning/FEATURE_TRACKER.md):

| Capture path | Backend support today | Required next work |
| --- | --- | --- |
| Barcode | Live product/nutrition lookup, separate exact snapshot identity/facts lookup and local v0.5.0 read-only historical report | Client scanner/manual entry, source choice and report UI; v0.5.0 hosted gate pending |
| Back-package image | Corrected confirmed nutrient/ingredient/declaration facts produce a local v0.5.0 sourced report without a barcode | OCR/correction, table interpretation and report UI; v0.5.0 hosted gate pending |
| Front-package image | Identified confirmed claim types can be checked against sufficient confirmed back-table facts | Name/brand/variant extraction, bounded candidate search, identity confirmation and front/back pairing |

Implemented enrichment accepts linked barcode, confirmed front identity and corrected back
ingredient/allergen/nutrient facts. Confirmed public facts save automatically;
extracted candidates remain staged/unverified, with anonymous write auth behind
the scenes and no separate Share action. Original observations retain dates/
sources; compatible fields may complement one another in a derived view while
conflicts remain visible. Client capture/background requests remain pending. [Lifecycle/source guide](../architecture/COMMUNITY_CATALOGUE.md).

Useful coverage should not depend on an operator reviewing each identical
rescan. Strictly validated identity-compatible gap fills can be usable
with submitter-confirmed/unreviewed provenance, while conflicts or identity
mismatches await review. Moderation is an additional state and cannot establish
current-package or safety proof. Public lookup includes qualified candidates and approved assertions; pending/provisional facts stay private.

There is no implemented image upload, OCR, front-image matcher, catalogue
search, ingredient-text parser or unified analysis endpoint. Current request
schemas reject raw photos and OCR bodies. The Flutter scanner is a starter.
Existing normalization and seven numerical claim checks should be reused.

## Source selection

The recommendations below distinguish product facts, regulatory evidence and
generic reference nutrition. They are not interchangeable datasets.

| Source | Recommended role | Acquisition decision and limits |
| --- | --- | --- |
| Open Food Facts | Primary barcode identity and source-tagged packaged-product facts; candidate metadata for front-text search | Existing India bundle is complete for its declared export filter. Preserve live exact lookup as a separately selected path. Future expansion needs measured market evidence, eligibility and reuse review. [Official licensing](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/) identifies ODbL database, DbCL contents and CC BY-SA images. Keep existing URL-descriptor policy; do not bundle image bytes. |
| FSSAI | Reviewed claims, ingredient/additive context, applicable category rules and explanation references | Continue bounded manual curation from authoritative provisions and amendments. Existing seven-rule knowledge stays active; a broader glossary needs its own review. [Food-'O'-Copoeia](https://foodocopoeia.fssai.gov.in/about.aspx) is a category-wise standards reference and says original regulations/notifications prevail. It is not established here as a branded barcode catalogue. Full documents are not runtime bundles. |
| ICMR-NIN IFCT 2017 | Possible Indian raw-food composition reference | Hold product ingestion pending permission. [Publisher front matter](https://www.nin.res.in/ebooks/IFCT2017_16122024.pdf) requires prior written permission for electronic storage/reproduction to create a product. Public reading and third-party mirrors do not establish that permission. |
| Indian Nutrient Databank (INDB) | Possible separate Indian generic-food/standard-recipe reference | [Authors' paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC11277795/) describes 1,095 raw foods and 1,014 recipes and identifies missing packaged-food nutrients as a limitation. [Original repository](https://github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-) and [author portal](https://www.anuvaad.org.in/indian-nutrient-databank/) provide access, but dataset redistribution remains unverified. The article's CC BY license does not establish the external workbook's license; an [unresolved license request](https://github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-/issues/2) exists. Embedded workbook notices have not been inspected. |
| USDA FoodData Central | Optional generic ingredient nutrition reference; exact branded records only after identity/market review | [USDA distinguishes](https://fdc.nal.usda.gov/data-documentation/) analytical Foundation Foods, historic SR Legacy and manufacturer-label Branded Foods. [Data are CC0](https://fdc.nal.usda.gov/api-guide/). If a reference feature needs it, start with Foundation Foods, then add measured SR Legacy gaps. No measured India-specific gain currently justifies the whole Branded/all-types dump. |
| Manufacturer data | Targeted missing-product and current-variant facts | Register each source, permission, identity, market and revision before importing. Public web visibility is not an automatic redistribution grant. No general manufacturer feed has been selected or acquired. |

USDA's [download page](https://fdc.nal.usda.gov/download-datasets/) currently lists
April 2026 Foundation JSON at approximately **459 KB compressed / 6.5 MB
expanded**, and April 2018 SR Legacy JSON at **12.3 MB / 205 MB**. These are
publisher estimates, not measured transfers. Recheck versions, rights and actual
hashes at acquisition time. Their inclusion would not directly increase the
number of packaged products with confirmed nutrition.

## How the three paths should connect

All three paths should produce one future report from explicit observations:

1. **Barcode:** retain the exact scanned identifier and source outcome. A
   snapshot miss permits a separately selected live lookup or confirmed-label
   intake; the current snapshot route must keep its no-automatic-OFF behavior.
2. **Back image:** extract nutrition tables, ingredient text and declarations
   with local region references. Preserve units, serving size, per-100-g versus
   per-100-mL basis, preparation state and incomplete panels. Review/correct
   recognized values before sending the supported structured facts. Permit an
   unnamed/unmatched product when sufficient label facts exist.
3. **Front image:** extract name, brand, variant, net quantity and stated claims
   into candidates. Search identity metadata and preserve ambiguity between
   flavours, sizes and reformulations. A candidate requires confirmation before
   its facts are associated with the capture. Front-only analysis can describe
   observed text; absent nutritional evidence stays unknown.
4. **Pair evidence:** front and back captures must belong to the same product.
   Keep request/session/revision and region IDs so a correction invalidates
   dependent findings. Similar-looking packaging is not proof of a match.
5. **Compose a report:** retain source-specific fields and conflicts. Reuse
   normalization/claim checks where applicable; new ingredient explanations,
   allergy evidence or scoring require their own reviewed implementation.

The planned photo paths keep photos and raw OCR local. Future backend intake
would accept public confirmed fields, not an arbitrary image URL or photo body.
Existing analysis origins/limits remain unchanged. v0.4.0 automatic persistence
accepts structured public facts and private provisional observations; photos/raw
OCR/profiles/history stay private. These APIs are mounted locally.

Current-package confirmed values should be selected for assessment while
retaining contradictory provider values. Each field needs source/date/revision,
basis, completeness and quality/confirmation state. A derived resolved view can
complement compatible known fields across product sources, retaining whole
original observations. Never average conflicts, splice incompatible tables or
fill missing packet nutrients from generic food composition.
For example, an unknown fibre value in branded oats stays unknown even if USDA
or IFCT contains a generic oats value. A recipe estimate would need a separate
labelled output and cannot support a packaged-product claim check.

Do not use a barcode prefix to infer Indian manufacture or Indian retail
availability. [GS1 explains](https://support.gs1.org/support/solutions/articles/43000734188-does-the-gs1-prefix-first-3-or-4-digits-of-the-ean-13-barcode-number-show-the-country-of-origin-)
that the prefix does not indicate where a product was manufactured. The
snapshot market tag also cannot prove completeness of products sold in India.

## Language coverage

Keep English/Hindi explanation coverage separate from OCR script coverage.
Context7's official ML Kit documentation and the [supported-language list](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages)
identify Latin, Devanagari, Chinese, Japanese and Korean script models. The
planned native choice therefore does not establish support for every Indian
script. Start by validating English and Devanagari package text; do not infer
recognition quality from SDK support alone.

For Bengali, Tamil, Telugu, Kannada, Malayalam, Gujarati and other desired
scripts, evaluate a separate adapter/model and retain manual correction.
[Tesseract language data](https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html)
offers additional candidates; [Tesseract.js](https://github.com/naptha/tesseract.js)
supports local browser OCR with selected language models. Model existence does
not prove packaging accuracy or an acceptable download/latency budget. Download
only selected models and verify their licenses/hashes. No paid vision service
or all-language download is required by this proposal.

## Work tracker and sequence

These are work packages. v0.4.0 enrichment is implemented locally and Firebase
is configured; hosted publication passed independently. Search/OCR/report work
is separate. Finish one accepted version at a time.

| Work package | Goal and completion evidence | Current state |
| --- | --- | --- |
| Existing product foundation | Reuse validated OFF India source, exact live/snapshot contracts and reviewed seven-claim bundle | Released; source scope remains limited |
| Source selection and gap audit | Record roles/rights, three capture-path gaps and honest field denominators | This research complete; no new source bundle acquired |
| Automatic public product enrichment | Save/dedup confirmed barcode/front/back facts; stage candidates as unverified; compatible per-field sources with original observations retained | v0.4.0 released; Firebase and hosted checks passed; [review](../planning/BACKEND_V0_4_0_REVIEW.md) |
| Coverage measurement and front-text search | Bounded name/brand/variant candidates; reproducible missing-field and category/language counts; no false exact matches | Proposed backend slice |
| Confirmed package analysis and report | Sufficient corrected facts produce a useful report; current/historical evidence, unknowns and conflicts stay distinct | Normalization/claim subset released; local v0.5.0 report passes focused API/contracts, release gates pending |
| Ingredient glossary and wider evidence | Reviewed Indian ingredient aliases/INS, English/Hindi explanations and declaration distinctions | Local v0.5.0: three reviewed English/Hindi technological-function entries; wider coverage pending |
| Capture/OCR integration | Three entry modes, local capture/correction and useful reports on devices/web | Frontend work pending; SDKs not installed |
| Regional coverage expansion | Measure missing regional/local/imported products and scripts, acquire only sources that improve those gaps | Pending benchmark and rights review |
| Optional generic-food reference | Separate raw-food/recipe facts with licensed composition and visible limits | USDA optional; IFCT/INDB rights unresolved |

The next acquisition should follow a measured need: reviewed ingredient/source
metadata and permitted product-gap sources first, optional USDA references only
when a separate feature consumes them. Retain source-specific bundles with
publisher/version, license/permission, URLs, actual byte/hash receipts, row
counts, normalization rules, exclusion reasons and refresh policy. Do not put
new sources into the existing two-file claim bundle without a reviewed build
and contract change. Generated databases remain generated.

All future download/import stages need honest progress: bytes when total size
is known, records processed when counted, elapsed/stage status otherwise. The
existing setup/acquisition progress helpers remain the baseline; no fabricated
percentage or scripts promising acquisition of permission-gated sources.

## Measuring useful coverage

Begin with a proposed **200-product evaluation set across 20 categories**,
ten products per category, mixing national/regional brands, local small brands,
imports, clear/curved/glared labels, supported and unsupported scripts, and
similar variants. These are evaluation targets, not collected fixtures or a
statistically representative survey of India. Suggested categories are dairy,
plant drinks, biscuits, breads, breakfast cereals, grains/flours, pulses,
noodles/pasta, namkeen/chips, nuts/seeds, sweets/chocolate, bars, juices/drinks,
tea/coffee, oils/ghee, spices/masalas, sauces/pickles, ready-to-eat meals, frozen
foods and packaged mixes. Product-category applicability still needs review.

Use original synthetic fixtures or explicitly permitted public examples for
tracked tests. Real scans/private metadata must not enter Git; keep any
authorized local evaluation captures ignored. Continue the official-image URL
descriptor boundary rather than bundling provider image binaries.

Report separate numerator/denominator and dated source versions for:

- **Barcode recognition and lookup:** decoded code correctness, identity hit
  rate, snapshot versus live hit rate, and fields available on returned records.
- **Back-label extraction:** exact nutrient/value/unit/basis accuracy against
  reviewed ground truth, ingredient/declaration transcription and correction
  rate. A successfully processed image is not necessarily correct extraction.
- **Front-label matching:** correct candidates, confirmed exact identity,
  ambiguity/abstention rate, claim text accuracy and wrong-variant association.
- **Analysis:** sufficient-input rate per reviewed rule, unknown/conflict rate,
  and whether explanations cite the actual confirmed evidence.
- **Coverage gaps:** category, regional brand, script, market evidence and
  provider origin. Count records and useful fields separately.
- **Practical cost:** asset bytes, memory, recognition latency, failure/retry
  rates and actual device/browser results while retaining the no-card budget.

Do not combine these into an unsupported "Indian food coverage percentage."
Expand the corpus and language support based on measured failures. Review docs,
scripts, affected tests/contracts, source rights and dead-code findings before
each implementation push, as required by [workspace instructions](../../AGENTS.md).
