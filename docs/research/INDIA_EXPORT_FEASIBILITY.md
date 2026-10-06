# India export feasibility — 6 October 2026

Checked **2026-10-06** for the separate backend v0.2.1 snapshot milestone. Context7 resolved `/openfoodfacts/openfoodfacts-server`; official documentation, current upstream source and bounded HTTP checks supplied this note. Hugging Face's Dataset Viewer documentation was separately resolved through Context7. At the initial research checkpoint, no bulk dataset, image, index or sample file was retained. After the user authorized a larger internet transfer, the coordinating agent began a separate global-CSV stream acquisition; its reported header evidence and the verified dialect are recorded below. This research note changes no app code and schedules no import.

**Result at the initial research checkpoint:** India-tagged product access is verified, including two current v3.6 structured nutrition reads. A complete, usable India bulk export is **not yet verified**. The documented filtered CSV route timed out, then returned 503; current default upstream code limits on-demand exports to 10,000 products, whereas one bounded India query counted 24,706. Official global exports are accessible through HEAD, but substantially larger than the proposed 1 GB retained-work budget. The later authorized global-CSV GET returned 200 and a real header, so streaming acquisition has concrete source evidence. Full transfer completion, India output size and completeness still require the coordinating agent's acquisition manifest and validation. Do not activate a production catalogue or label two API samples a complete India snapshot.

## Later full-source acquisition, verified by the coordinating agent

After explicit authorization for a large transfer, the full documented global CSV stream completed on 6 October (05:15:46–05:22:19 UTC): **1,275,171,186 compressed bytes**, gzip EOF verified and SHA-256 recorded. It scanned **4,535,553** rows and retained **21,188** exact India-tagged rows. The corrected identity projection is **6,588,910 bytes**; **21,138** supported barcodes form an **11,993,088-byte SQLite index**. Fifty unsupported codes are counted; no supported exact duplicates or leading-zero equivalence collisions were found. Aggregate nutrients, images, per-record modification dates and legacy incomplete allergen tags are omitted.

This supersedes the initial bulk-acquisition uncertainty below. It does not resolve market coverage or the **24,706** live-search count difference. Ingredient text is missing in **15,780** indexed records; name missing in **3,442**. Rice flour sample is present; the live-found chocolate sample is absent. Source coverage remains independently unverified. [Hashes, timings, actual local checks and remaining hosting gates](../planning/BACKEND_V0_2_1_REVIEW.md). The latest user preference is manual **nine-month** replacement; full world data was streamed, not stored, and no automatic job was scheduled.

## Documented acquisition routes

The [official data page](https://world.openfoodfacts.org/data) states that exports are generated nightly and links global JSONL, compressed CSV and OFF's Parquet dataset on Hugging Face. It also links the [advanced search form](https://world.openfoodfacts.org/cgi/search.pl) for filtered CSV downloads. The data page was genuinely reachable from the shell: HTTP 200, 63,812 bytes. A browser-crawler restriction is not evidence that OFF's data service is inaccessible.

The live advanced-search form and [official form template](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/templates/web/pages/search_form/search_form.tt.html) establish these inputs:

| Parameter | India CSV value | Evidence |
| --- | --- | --- |
| `action` | `process` | Hidden form input |
| `tagtype_0` | `countries` | Country criterion; `countries` is an accepted search field |
| `tag_contains_0` | `contains` | Inclusion predicate |
| `tag_0` | `en:india` | Country taxonomy ID, canonicalized by the server |
| `download` | `1` | Non-empty download input selects export behavior |
| `format` | `csv` | Form's CSV radio value |

The form submits to `/cgi/search.pl`; [the official CGI implementation](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/cgi/search.pl) reads these parameters, constructs `countries_tags = en:india` and calls `search_and_export_products`. The tested GET URL was constructed from those documented inputs, rather than a guessed static country filename:

~~~text
https://world.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=countries&tag_contains_0=contains&tag_0=en%3Aindia&download=1&format=csv
~~~

[Current export dispatch code](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Display.pm) sets a default `export_limit = 10000`, allows a deployment option to change it, and allows an administrator to override it. Its export function returns an error if the matching count exceeds the configured maximum; it does not certify a complete 24,706-row India download. **The production override is unknown.** Neither failed request established that the product-count limit caused the failure.

No dedicated static India JSONL/CSV URL or India shard was found in the official data page, advanced-search sources, official exports README or HF dataset metadata inspected here. This is a bounded documentation finding, not proof that OFF cannot provide one. The [reuse wiki](https://wiki.openfoodfacts.org/Reusing_Open_Food_Facts_Data) returned HTTP 200 with a 4,414-byte bot challenge, so its actual documentation was not available.

## Actual bounded HTTP evidence

All initial research reads used `User-Agent: Unlabel/0.2.1 (backend snapshot feasibility; bounded read)`, `Accept-Encoding: identity`, explicit timeouts and a **1,048,576-byte body ceiling per request**. No initial request reached that body ceiling. There was no pagination loop, per-barcode bulk extraction, image fetch or full-world download in those checks. The first filtered CSV attempt allowed 20 seconds; the second had a 55-second overall deadline and 50-second HTTP timeout. Initial raw responses lived only in short-lived Python memory and were not saved. The later user-authorized acquisition has a separate transfer budget and completion evidence; the initial 1 MiB research ceiling is not its full-transfer ceiling.

| Check | Result | Body read | Interpretation |
| --- | --- | ---: | --- |
| Official data page | 200; `text/html; charset=UTF-8` | 63,812 B | Documentation reachable |
| Advanced-search form | 200; `text/html; charset=UTF-8` | 149,918 B | Actual form reachable |
| India CSV attempt 1 | Read timeout after 20.36 s; no headers obtained | 0 B | HTTP status, format, size and rows unknown |
| India CSV attempt 2 | 503 after 0.83 s; `text/html`; `Content-Length: 25281` | 25,281 B | Error page; no CSV header or product rows |
| India v2 count + one identity | 200 after 0.56 s; `application/json; charset=utf-8` | 197 B | Matching count 24,706; one India identity |
| India v2 two-record sample | 200 after 0.73 s; `application/json; charset=utf-8` | 5,665 B | Two current identities/field gaps, not a bulk export |
| Rice-flour v3.6 product | 200 after 0.70 s; `application/json; charset=utf-8` | 2,642 B | Structured nutrition and schema 1004 verified |
| Chocolate v3.6 product | 200 after 0.84 s; `application/json; charset=utf-8` | 15,439 B | Structured declarations and estimates remain distinct |

The count query was exactly:

~~~text
https://world.openfoodfacts.org/api/v2/search?countries_tags=en%3Aindia&page_size=1&page=1&fields=code%2Cproduct_name%2Ccountries_tags%2Cschema_version&sort_by=last_modified_t
~~~

The separate two-record check used `page_size=2`, `page=1`, the same country/sort parameters and fields `code,product_name,brands,quantity,ingredients_text,allergens_tags,traces_tags,last_modified_t,schema_version,countries_tags,nutriscore_grade,nova_group,nutrition,nutriments`. It returned `count: 24706`, `page_count: 2`, and the two records below. This count is a dated query result, not a unique normalized-barcode count, market census or completed-import count. Missing India tags can omit products sold in India.

| Barcode | Observed public identity | Field observations |
| --- | --- | --- |
| `7622202842450` | Dairy milk silk roast almond; Cadbury Dairy Milk; `36g` | Ingredients present; allergens `en:milk,en:nuts,en:soybeans`; traces `en:gluten,en:nuts`; `last_modified_t = 1791261799` |
| `8904083506393` | Organic Rice Flour-500g; 24 Mantra Organic; `500g` | Ingredients absent; allergens/traces empty; `last_modified_t = 1791261493` |

Both v2 sample responses had `countries_tags: ["en:india"]`, `schema_version: 998` and legacy `nutriments`, without structured `nutrition`. The subsequent v3.6 reads of the **same products** had `schema_version: 1004` and structured `nutrition.input_sets`. API response conversion/version therefore cannot establish the stored schema distribution of the bulk dump. Empty allergen arrays are not a package-verification or allergy-safety conclusion.

The v3.6 requests selected `code,product_name,brands,quantity,ingredients_text,allergens_tags,traces_tags,countries_tags,last_modified_t,schema_version,nutrition`:

- [Rice flour 8904083506393](https://world.openfoodfacts.org/api/v3.6/product/8904083506393.json?fields=code,product_name,brands,quantity,ingredients_text,allergens_tags,traces_tags,countries_tags,last_modified_t,schema_version,nutrition): one `packaging / as_sold / serving` table, `per_quantity: 30`, `per_unit: g`, 12 nutrients; direct fat `0.3 g`, sugars `0 g`.
- [Chocolate 7622202842450](https://world.openfoodfacts.org/api/v3.6/product/7622202842450.json?fields=code,product_name,brands,quantity,ingredients_text,allergens_tags,traces_tags,countries_tags,last_modified_t,schema_version,nutrition): a `packaging / as_sold / 100g` table with 12 nutrients and a separate `estimate / as_sold / 100g` table with 66 nutrients. The estimate fat/sugar rows had `~` modifiers. The existing direct-declaration adapter can retain that distinction.

These are community-record schema observations, not verified package facts. The original objects were no longer retained when saving samples was requested, so **no `india-api-sample.jsonl` or sidecar was created** and no additional read was made. A future two-record fixture must declare acquisition kind `api_sample`, its exact URLs/date and incomplete coverage.

## Measured global exports and storage

The documented static URLs returned 302 to OFF's S3 bucket. HEAD requests to those returned locations succeeded with `application/gzip`, `Accept-Ranges: bytes`, and the following actual `Content-Length` values; **zero body bytes were downloaded**:

| Documented file | Returned source | Compressed bytes | Source Last-Modified |
| --- | --- | ---: | --- |
| [Global JSONL](https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz) | [OFF S3 JSONL](https://openfoodfacts-ds.s3.eu-west-3.amazonaws.com/openfoodfacts-products.jsonl.gz) | **13,077,575,686** (13.08 GB / 12.18 GiB) | 2026-10-05 06:44:17 GMT |
| [Global CSV](https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz) | [OFF S3 CSV](https://openfoodfacts-ds.s3.eu-west-3.amazonaws.com/en.openfoodfacts.org.products.csv.gz) | **1,275,171,186** (1.28 GB / 1.19 GiB) | 2026-10-05 12:19:34 GMT |

The page's approximate CSV sizes are not the measurements above. Source compression, unpacked bytes, transfer bytes, working storage, compact-index bytes and deployment bundle bytes are separate budgets. Retaining either global gzip would already exceed the proposed 1 GB work-directory budget. Streaming selection without retaining the world dump is technically possible in principle, but was not performed. A 24,706 matching-record count alone cannot establish a <=100 MB index, <=1 GB replacement workspace or serverless deployment fit.

OFF describes its public data/API as free; these checks used no account, payment card or credentials. This verifies read access at ₹0, not a free hosting/storage service or a successfully deployable catalogue. Keep the backend snapshot separate from app storage. Keep one active catalogue; manually build and validate its replacement every nine months with temporary overlap and a short rollback window, as in [the snapshot proposal](INDIA_SNAPSHOT.md). A scan request must not run a bulk download.

## Current format and nutrition/provenance boundaries

**Global JSONL:** the [official export script](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/scripts/export_products_data_and_images.pl) runs MongoDB export without a field projection. It can preserve the stored product object, including structured nutrition where present. It is a raw database export, not an API v3.6 response. Its schema distribution, missing-field coverage and India-row count were not sampled or measured here; parse declared/observed schema and fail explicitly for incompatible shapes.

**Nightly global CSV:** the [global CSV generator](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/scripts/export_database.pl) writes UTF-8 tab-delimited columns, canonical `*_tags`, timestamps, selected identity/ingredient fields and nutrient `*_100g` columns. Current code reads those nutrient values from `nutrition.aggregated_set`, which may be per 100 g **or** per 100 mL. It does not export the direct input-table structure or all source/unit/basis metadata. Do not reinterpret a flat `_100g` column as a verified packaging declaration or silently assume a mass basis. The [linked field-description file](https://static.openfoodfacts.org/data/data-fields.txt) was HTTP 200, 4,763 bytes, but its Last-Modified was **2020-05-29**; its legacy field list is not the current observed header.

**Later real-header check, 2026-10-06:** the coordinating agent reported HTTP **200** for the documented global compressed CSV and decoded a **3,346-byte header**, confirming actual identity, country-tag and ingredient columns. The observed allergy columns were exactly `allergens`, `allergens_en`, `traces`, `traces_tags`, `traces_en`; **`allergens_tags` was absent**. This is stronger evidence than the older field-description file and differs from current main-source header generation. It establishes a usable stream origin and observed header, rather than complete source traversal or a complete India projection. Header names must drive field mapping, with normalized tag columns distinguished from untranslated/free-text fields. The coordinating agent owns the acquisition manifest, exact captured header, stream progress and final completion measurements.

**Verified nightly dialect and parser diagnosis:** the current [nightly generator, lines 89–98](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/scripts/export_database.pl#L89-L98) replaces ASCII control characters, including embedded tab, LF and CR, with spaces. It then [concatenates literal field values and tabs](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/scripts/export_database.pl#L356-L363), and [replaces the final separator with a newline](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/scripts/export_database.pl#L472-L477). It applies **no double-quote wrapping, quote doubling or backslash escaping**. Double quotes and backslashes remain ordinary product text. Its format is therefore plain TSV with quoting disabled. A default Python CSV reader can wrongly interpret text beginning with a double quote as a quoted field; strict quote parsing then raises errors such as `'\t' expected after '"'` or incorrectly combines physical lines.

For this specific nightly file, use a bounded UTF-8 physical-line parser or the equivalent explicit CSV settings:

~~~python
csv.reader(lines, delimiter="\t", quoting=csv.QUOTE_NONE,
           quotechar=None, escapechar=None, strict=True)
~~~

Retain header uniqueness, exact cell-count checks, per-line/field/decoded-stream budgets and gzip EOF verification. Do not strip literal quotes or backslashes from field values. Embedded quoted newlines are not part of this generator's format; that test belongs to a separate quoted CSV source. The [local-cache tutorial](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/creating-a-local-cache-of-open-food-facts-data/) does not define this dialect, and no applicable official reader example was established in the bounded documentation search; the actual producer implementation is the primary dialect evidence.

**Observed legacy allergy-column semantics:** the official [2026-03-31 writer revision, `ccb79b847c062672b891c0e4a18b2edd0f16c232`](https://github.com/openfoodfacts/openfoodfacts-server/blob/ccb79b847c062672b891c0e4a18b2edd0f16c232/scripts/export_database.pl#L104-L121) contains a singular `allergen` entry in its tag-field map. Its exported field is plural `allergens`, so that revision emits the stored bare field and localized `allergens_en`, without an `allergens_tags` column. It [writes the stored field directly](https://github.com/openfoodfacts/openfoodfacts-server/blob/ccb79b847c062672b891c0e4a18b2edd0f16c232/scripts/export_database.pl#L326-L357), using the same literal-TSV dialect. This reproduces the observed naming; it does **not** prove the exact code revision deployed for this dump.

In the matching historical [allergen computation](https://github.com/openfoodfacts/openfoodfacts-server/blob/ccb79b847c062672b891c0e4a18b2edd0f16c232/lib/ProductOpener/Ingredients.pm#L8211-L8240), the bare `allergens` field is regenerated as a comma-separated taxonomy hierarchy from entered allergens. Ingredient-derived allergens are then combined separately into `allergens_tags`. The bare export field therefore cannot be assumed equivalent to the final normalized `allergens_tags` array, even when its cells contain plausible `en:*` values. Syntax validation cannot recover omitted ingredient-derived allergens or verify a package declaration. For the initial identity projection, omit/map it to unknown with a clear warning, or preserve a distinct limited-field origin; never silently rename it and claim complete canonical allergen coverage. Use the actual normalized `traces_tags` column for traces, subject to normal validation. A header-only evidence check does not establish how frequently any of these fields are populated across India products.

The nightly generator also reads **both active and obsolete product collections** and does not upgrade stored product schemas during export. Its filtered India count may consequently differ from a live search count; measure obsolete/duplicate handling explicitly rather than force the projection count to equal 24,706.

**Filtered-search CSV is a different generator and dialect:** [Export.pm](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Export.pm#L534-L544) uses `Text::CSV` with tab separation and quote handling; it is not the nightly literal-TSV writer. Together with [Nutrition.pm](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Nutrition.pm), it now generates dynamic populated columns such as:

~~~text
nutrition.input_sets.<source>.<preparation>.<per>.per_quantity
nutrition.input_sets.<source>.<preparation>.<per>.per_unit
nutrition.input_sets.<source>.<preparation>.<per>.unspecified_nutrients
nutrition.input_sets.<source>.<preparation>.<per>.nutrients.<id>.value
nutrition.input_sets.<source>.<preparation>.<per>.nutrients.<id>.unit
nutrition.input_sets.<source>.<preparation>.<per>.nutrients.<id>.value_string
nutrition.input_sets.<source>.<preparation>.<per>.nutrients.<id>.modifier
~~~

This code can preserve more direct-table context than nightly CSV. It includes only populated fields, and the web dispatch enables computed fields, including estimated input sets. The helper keys tables by `source / preparation / per`; duplicate tables with the same key overwrite in the helper, so original input-array identity/conflict preservation is not guaranteed. Its default nutrition projection does not carry every table metadata field, such as `source_description` and `last_updated_t`. **No live India CSV header was obtained**, so current deployed behavior/columns remain unverified; do not promise that this route equals full JSONL or feeds the v3.6 adapter unchanged.

The current backend `Source.upstream_api_version` is a strict `Literal["3.6"]`. A snapshot read therefore requires an explicit export/source identity contract instead of claiming its bytes came from API 3.6. Track acquisition kind/format, source URL, source/export date, actual fetch date, checksum, selection predicate, importer/schema version, snapshot ID and per-record modified time. Keep provider facts, user-confirmed rows and reviewed rule findings separate. Preserve unknown values, leading-zero barcode strings and unsupported-field reasons. See [v3.6 adapter research](OFF_NUTRITION_V3_6.md).

## Official Hugging Face alternative

The [OFF dataset README](https://huggingface.co/datasets/openfoodfacts/product-database/blob/main/README.md) and [OFF export-service README](https://github.com/openfoodfacts/openfoodfacts-exports) document daily simplified Parquet conversion of the JSON dump. The inspected dataset declares **config `default`, split `food`**, with one food Parquet path and a separate beauty split; it does not declare an India split.

Three documented Dataset Viewer metadata calls succeeded without authentication, each below 1 MiB:

| Metadata endpoint | Status / body bytes | Observed food dataset |
| --- | --- | --- |
| [Parquet files](https://datasets-server.huggingface.co/parquet?dataset=openfoodfacts%2Fproduct-database) | 200 / 568 B | One file, **7,887,396,939 B** |
| [Schema info](https://datasets-server.huggingface.co/info?dataset=openfoodfacts%2Fproduct-database&config=default) | 200 / 8,208 B | 111 columns; `countries_tags` is list of strings |
| [Size/count](https://datasets-server.huggingface.co/size?dataset=openfoodfacts%2Fproduct-database) | 200 / 929 B | **4,779,997 food rows**; reported uncompressed memory 22,869,865,769 B |

Current metadata has **no `nutrition` column**. It has a legacy `nutriments` list of structs with float32 `value`, `100g`, `serving`, prepared values and `unit`; `ingredients_text` is a list of `{lang,text}` structs. This cannot be assumed to preserve v3.6 direct input sets, modifiers and all provenance.

The [official `/filter` documentation](https://huggingface.co/docs/dataset-viewer/filter) documents scalar comparison/logical predicates and a maximum 100 rows per response. It does not document exact array-membership filtering for the observed `countries_tags` list. It also states that filtering can be partial for datasets over 5 GB, indexing only the first 5 GB. No array-filter syntax was invented and no pagination extraction was attempted. No complete India extraction, SQL export endpoint or country shard was verified. Remote Parquet column/range selection may merit a later measured experiment, but it is not established as a complete <=1 GB source acquisition here.

## Release boundary and remaining evidence

v0.2.1 may provide a bounded **local JSONL catalogue importer, validator, manifest and read-only lookup tools**, with fixtures and clear inactive production status. It must accept only a deliberately supplied source whose origin/schema/budget checks succeed; failed imports preserve the existing catalogue. A source made from a few API reads is a sample. Do not populate the catalogue by paginating the public search API or fetching every barcode; [OFF's API guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/) directs bulk consumers to exports and documents rate limits/global 503 responses. The cause of these particular CSV failures remains unknown.

Keep a separate v0.2.2 acquisition/hosting gate before claiming production snapshot readiness:

1. Full global CSV streaming is now verified for identity data. Investigate the live-search count gap and choose richer fields/provenance before claiming broad coverage or direct-label nutrition from a future snapshot.
2. Measure unique/rejected/duplicate/obsolete records, leading-zero equivalence/collisions, ingredient/allergen/nutrition gaps and unsupported schemas. Compare dated matching counts without claiming identical source times.
3. Measure transferred/unpacked bytes, peak memory, free disk and compact/index sizes, including active/replacement/rollback overlap. Enforce the explicit limits instead of silently truncating products.
4. Compare representative snapshot lookups with current live reads while keeping data age and provider errors visible. Verify the actual free deployment runtime, bundle budget and read-only access before enabling snapshot preference.
5. Validate checksum and manifest, replace atomically on the agreed manual nine-month cadence and clean only importer-owned expired artifacts after replacement succeeds.

Use the source [ODbL/database-content and attribution guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/) and [OFF reuse terms](https://world.openfoodfacts.org/terms-of-use). Public database reuse must retain OFF attribution and applicable ODbL/DbCL obligations; adapted public datasets require the applicable share-alike/open availability. Keep private scans and other product sources separate from the OFF catalogue. Images have separate CC-BY-SA terms and were not downloaded. No automatic write-back, contribution upload or private-data publication is authorized by this importer work.
