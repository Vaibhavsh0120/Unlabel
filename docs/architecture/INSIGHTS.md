# Reviewed editorial insights

Frontend v0.7.0+11 adds a complete offline reading collection alongside the
existing food-label workflows. This is editorial education, separate from
scanned product observations, private account records and compliance reports.

## Reader experience

The collection contains twenty distinct articles in Sugar, Fibre, Protein,
Claims, Ingredients, Tips and Swaps. Each has its own stable ID, title, summary,
generated illustration, reading estimate, three explanatory sections, one
practical takeaway, review date and primary-source references. Source links can
open in the browser or be copied, with an explicit failure message.

The All filter opens today's four articles: one featured card and three
supporting cards. Each topic filter opens every article in that topic, including
articles outside today's selection. Browse all 20 opens the complete collection;
Back to today's four restores the daily view. Nothing is locked behind an
account, API request or paid service.

Home and Insights use the same controller and selection. Desktop and mobile
Home both support manual swipes, four selectable dots, left/right keyboard
navigation and screen-reader adjustment. Dots keep 48 px width with compact
28 px height and a 4 px gap above, as requested after the rendered review. RTL direction,
reduced motion and enlarged text are preserved. Later user steering adds a
three-second Home rotation with a pause/resume control. Hover, focus, touch,
scrolling, background/covered routes, reduced motion and accessible navigation
pause rotation; manual controls remain available.
Every slide uses the corresponding article's artwork; different facts never
share a generic image. A saved preview and reader may repeat the same article's
image because they identify that same article.

Desktop retains the real sidebar, top search, Profile and selected Insights
destination. The feed sits beside saved insights, quick topics and the reference
botanical note. Phones retain the app header and show saved insights below the
feed. The daily list has four articles even though the reference mockups contain
more example cards. Enlarged text stacks the layout rather than clipping text.

## Daily selection

`InsightCatalogue.daily` uses the device's local calendar date to seed an explicit
Park-Miller shuffle. Four different topics are drawn, one article from each,
then their order is shuffled. The algorithm uses integer ranges that are exact
on both Dart VM and web. The same date selects the same four IDs and order,
including app restarts. It does not profile the reader or measure health needs.

The controller schedules the next local midnight and checks the date when the
app resumes. Home resets its selected slide when the day changes. Topic
browsing and saved articles remain available across daily changes. Random
selection can show an article on successive days; no five-day coverage promise
is made. A year of deterministic test dates reaches all twenty articles.

## Device bookmarks and failure handling

Only stable editorial article IDs are stored under the dedicated key
`unlabel.client.v1.insightBookmarks`, with schema version 1. No photos, raw OCR,
product records, dietary preferences, account identifiers or credentials enter
this document. These bookmarks are device-wide convenience data and never
enter private account sync. Their preview shows actual saves only, with a
useful empty state and a complete See all collection.

Writes update the UI only after storage succeeds. Failed writes retain the
previous saved state and report the error. Reads are bounded to 8 KiB, unknown
IDs are ignored and duplicates are removed. Malformed documents block writes
instead of silently replacing data. Retry coalesces overlapping reads; an
explicit confirmed Clear saved insights recovers a damaged document. Every
error recovery action is available in the feed and the article reader.

## Content and artwork maintenance

Articles cite reviewed FSSAI label/claim compendia, WHO dietary guidance and
Codex additive functions. A source's version/date stays visible; the editorial
review date is 9 October 2026. Arithmetic examples identify their invented
numbers. Unknown values remain unknown. Generic foods, decorative pictures and
claims cannot establish a current package's contents, suitability, allergy
safety, legal compliance or a universal health score.

The catalogue is a versioned, bundled Dart collection. To change an article,
review its source, update its copy and date, preserve its stable ID, retain the
existing bookmarks and run the content/controller/UI checks. New artwork must
match its article, have a unique subject and keep a complete transparent
silhouette. On 12 October the runtime images were converted to lossless WebP,
preserving every decoded RGBA pixel and the original dimensions. Current hashes
and recoverable PNG source identities are in the
[optimization manifest](../../frontend/assets/artwork/optimized-assets.json).
The historical [generation manifest](../../frontend/assets/artwork/insights/generation-manifest.json)
records exact prompts, dimensions and SHA-256 hashes. No image-generation API,
provider credential or billing dependency ships in the app.

The eight dietary preference choices and twelve allergen reminders also have
twenty distinct corresponding symbols. Their saved summaries use the same
mapping as the complete editors. The [icon provenance](../../frontend/assets/icons/README.md)
distinguishes original food pictograms from the retained Solar controls.

See the [original collection review](../planning/FRONTEND_V0_7_0_REVIEW.md)
and [current UI/auth review](../planning/FRONTEND_V0_8_0_REVIEW.md) for their
separate local, hosted and publication evidence.
