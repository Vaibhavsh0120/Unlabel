# Open Food Facts v3.6 nutrition adapter research

Historical research checked **2026-10-05** for backend v0.2.0; this file does not itself implement normalization or activate claim thresholds. The v0.4.0 source preserves that direct-table adapter, retains the independently verified v0.2.3 rich snapshot and adds a separate confirmed-label numerical claim subset; see the [current API](../../backend/README.md) and [current release gates](../planning/BACKEND_V0_4_0_REVIEW.md). Context7 resolved `/openfoodfacts/openfoodfacts-server`; current official schema/code and two bounded public product reads supplied the findings below.

## Version and selected product fields

API 3.5 introduced the structured nutrition representation; 3.6 adds the tags refactor (product schema 1004). Older generated documentation still shows flat `nutriments` suffixes. Do not implement v3.6 from those examples: the current nutrition schema uses `product.nutrition`. API/product-schema versions are different identities. [Official change log](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-api-and-product-schema-change-log/).

Request a bounded field selection: `code,schema_version,nutrition,serving_size,serving_quantity,serving_quantity_unit,last_modified_t`. Identity/source fields already needed by the product adapter can remain selected. Serving metadata is optional supporting information; it must not override contradictory table quantities. Full product records/images are unnecessary. [Product schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/product_v3.yaml), [product base fields](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/product_base.yaml).

| Path | Current meaning |
| --- | --- |
| `nutrition.input_sets[]` | Separate nutrition tables, each with its own source, preparation and reference quantity |
| table `source` | Examples: `manufacturer`, `packaging`, `usda`, `estimate`; schema does not close this string to an enum |
| table `preparation` | `as_sold` or `prepared` |
| table `per` | `100g`, `100ml` or `serving` |
| table `per_quantity`, `per_unit` | Numeric reference amount and its unit, e.g. 100/g or serving 330/ml |
| table `nutrients[id]` | Nutrient object containing numeric `value`, `unit`, optional `value_string`, `modifier`, `value_computed` |
| table `unspecified_nutrients[]` | Nutrients explicitly unspecified; never zero-filled |
| table `source_description`, `last_updated_t` | Optional origin description and update timestamp |
| `nutrition.aggregated_set` | Read-only derived combination of preferred sources, normalized to 100 g/100 ml |

[Structured nutrition schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/product_nutrition_v3.yaml), [basis/preparation schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/product_nutrition_properties.yaml).

Minimal **synthetic** input-table shape:

~~~json
{
  "source": "packaging",
  "preparation": "as_sold",
  "per": "serving",
  "per_quantity": 30,
  "per_unit": "g",
  "nutrients": {
    "fat": {"value": 1.2, "unit": "g", "value_string": "1.2"},
    "sodium": {"value": 80, "unit": "mg"}
  }
}
~~~

## Narrow nutrient map

| Unlabel quantity | OFF nutrient ID | Normalized unit / distinction |
| --- | --- | --- |
| Energy, kcal | `energy-kcal` | kcal |
| Energy, kJ | `energy-kj` | kJ |
| Fat | `fat` | g |
| Saturated fat | `saturated-fat` | g |
| Available carbohydrate | `carbohydrates` | g; excludes fibre |
| Total carbohydrate | `carbohydrates-total` | g; US/Canada gross definition includes fibre; keep separate |
| Total sugars | `sugars` | g |
| Added sugars | `added-sugars` | g; missing does not mean none added |
| Fibre | `fiber` | g; singular American spelling in the key |
| Protein | `proteins` | g; plural in the key |
| Sodium | `sodium` | g internally; input mg must be converted explicitly |
| Salt | `salt` | g; distinct from sodium |

These IDs are documented in the [current nutrient schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/nutrients_v3_base.yaml). Input units are explicit and may differ from the normalized unit. `energy` is a kJ alias/derived field, not a replacement for dedicated energy rows. [Default-unit implementation](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Nutrition.pm).

## Values, bases and provenance

`value` is numeric and may be **0**. `value_string` preserves contributor text; `value_computed` is system-derived, not a label declaration. Optional modifiers are `<`, `<=`, `~`, `>=`, `>`; do not convert qualified observations into exact values. Missing/null/invalid rows remain unknown. Reject booleans, nonfinite/negative numbers, unsupported units and malformed text. [Nutrient-value schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/nutrient_values_v3_base.yaml), [value-string schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/nutrient_values_v3_with_value_string.yaml).

- `100g` and `100ml` are separate reference dimensions. Check supplied quantity/unit consistency; no density-based conversion is assumed.
- A `serving` table remains per serving. Derive a 100 g or 100 ml view only with a known positive serving quantity in the matching dimension: `value × 100 / quantity`.
- Preserve `prepared` and `as_sold` tables separately; no dilution/recipe conversion is inferred.
- Restrict initial mass units to reviewed g/mg conversions; retain unsupported-unit unknowns. Energy conversion uses 4.184 kJ/kcal and must identify derived output rather than overwrite declarations. OFF itself rounds some conversions, so exact cross-unit equality is not promised. [Units implementation](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Units.pm).

Aggregation prefers prepared before as-sold, then manufacturer/packaging/USDA/estimate, and can fill computed energy/salt/sodium values or ingredient estimates. It may combine different input tables. Aggregated nutrients carry `source`, `source_per`, `source_index`; these do not certify a scanned package. Do **not** use the aggregate for the initial direct-declaration adapter. [Aggregation code](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Nutrition.pm), [aggregate provenance schema](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/nutrients_source_v3.yaml).

## Bounded public checks

- [3017620422003](https://world.openfoodfacts.org/api/v3.6/product/3017620422003.json?fields=code,schema_version,nutrition,serving_size,serving_quantity,serving_quantity_unit,last_modified_t): observed manufacturer 100 g and 15 g serving tables, a conflicting packaging table, and estimated nutrients. Some sodium rows had only `value_computed`; some direct rows contained zero. These are schema observations, not verified food facts.
- [5449000000996](https://world.openfoodfacts.org/api/v3.6/product/5449000000996.json?fields=code,schema_version,nutrition,serving_size,serving_quantity,serving_quantity_unit,last_modified_t): schema 1004; an empty 100 g table, populated 100 ml and 330 ml serving tables, estimated added sugars, and `aggregated_set.per = 100g`. Serving figures conflicted. Choosing the first table/aggregate would conceal relevant basis/conflict information.

Each read used an application User-Agent, timeout and 1 MiB response ceiling. No datasets, images or snapshots were saved. Both examples were as-sold; a live prepared record was **not** verified. Records can change.

## Recommendation for v0.2.0

Normalize bounded `input_sets` independently. Initially accept direct finite numeric `value` rows from supported manufacturer/packaging tables with known preparation/basis/unit; ignore `value_computed`, estimates and the aggregate. Treat qualified values as unsupported/unknown until interval handling exists. Preserve table/source/field paths and conflict warnings; never silently merge competing declarations. Unknown nutrient IDs may be ignored without breaking product lookup.

For confirmed structured label intake, require explicit nutrient ID, amount/unit, reference quantity/unit, preparation and input provenance. Keep user-confirmed package data distinct from OFF community data; a matching barcode does not verify a table. Preserve original rows plus derived-unit/basis provenance and unknown reasons. This release needs normalization tests, not health scores, medical claims or unreviewed legal thresholds. Distribution of schemas across the entire corpus remains unverified.

## India availability check — 2026-10-05

Product-by-barcode fetching is demonstrably possible: the two v3.6 product reads above returned structured nutrition. This does not establish India coverage, corpus completeness or availability of a complete country export.

Exactly **one** India-filtered search was attempted, requesting at most two identities plus nutrition-field availability:

~~~text
GET https://world.openfoodfacts.org/api/v2/search
countries_tags=en:india&page_size=2&page=1
fields=code,product_name,countries_tags,schema_version,nutrition,nutriments
sort_by=last_modified_t
~~~

The request used the application User-Agent, a 12-second HTTP timeout, a 15-second overall deadline and a 1 MiB decoded-response ceiling. It returned **HTTP 503 in 1.03 seconds**, with a 25,281-byte HTML error page. No product records were returned, so neither two India identities nor their nutrition-field availability was verified. The search was not repeated. This observation does **not** mean India products are unavailable. OFF documents global rate limiting that can return 503; the cause of this particular response was not established. [Official API guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/).

Structured search currently uses v2; `/api/v3/search` is not implemented. Country tags describe markets where products are sold, not manufacturing origin or a verified match to a current Indian package. v2 search responses must not be presumed to share v3.6 nutrition/tags representations. [Official search reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-cheatsheet/), [product country fields](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/ref/schemas/product_base.yaml).

The [official data page](https://world.openfoodfacts.org/data) was fetched separately as documentation: **HTTP 200**, 63,812 bytes. It documents nightly [global JSONL](https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz), [global compressed CSV](https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz), and filtered CSV through the linked [advanced-search form](https://world.openfoodfacts.org/cgi/search.pl). It did not list a dedicated India-export URL. Its linked official reuse wiki was inaccessible to the browser crawler. A browser-crawler error therefore must not be described as proof that the data server or exports cannot be accessed.

**India export status remains unverified:** no documented direct India-export endpoint was established, so no HEAD request was sent to a guessed URL. No export, dataset or images were downloaded. Filtered-export completeness, current India record count, file size, nutrition-schema distribution and hosting feasibility still require separate bounded verification. Bulk acquisition must use documented exports rather than paginating searches or fetching every barcode. Keep provider failures, missing nutrition and user-confirmed package data distinct.
