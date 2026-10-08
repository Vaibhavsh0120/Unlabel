# Popular products: internet facts in the app database

Accepted scope, 8 October 2026: gather ingredients, declared allergens, nutrition,
variant/pack identity and provenance for popular Indian packaged foods from
manufacturer and retailer websites. Open Food Facts is an additional source.
The result must enter a served database and be accessible in the app.

## Implementation

1. Inspect underlying product pages discovered through Google/web search; AI Mode
   is discovery only. Keep manufacturer, retailer and OFF observations distinct.
2. Preserve each dated source observation with an immutable hash in
   `data/catalogue/popular-india-v1/`. Missing GTINs stay null; product-family
   pages and ambiguous packs cannot establish exact barcode identity.
3. Build a separate verified SQLite researched-product store from that source.
   The backend build packages it, and local setup restores it without acquisition.
4. Expose bounded name/brand/variant search, immutable entry details and qualified
   exact-barcode alternatives through three additive read-only APIs.
5. Include researched records in Flutter Search alongside existing catalogue
   results. Display ingredients, contains/may-contain, reported nutrition basis,
   source dates, conflicts and additional unconfirmed website tables.
6. Review source/import/cursor/process boundaries, test app workflows, update
   contracts/docs, push backend and frontend independently, then verify hosting.

## Evidence and boundaries

The [product inventory](../research/POPULAR_PRODUCTS_ADDED.md) records products,
packs, source URLs and field availability. The dataset manifest records actual
counts/hashes. Neither record establishes complete Indian retail coverage.

No manufacturer/retailer fact is relabelled as OFF, CC0 community data or a
user-confirmed current package. Website observations remain dated source facts.
Retailer transcription and uncertain tables keep their qualification. Conflicts
are never averaged. Generic-food averages, foreign formulas and category-average
nutrition cannot fill Indian branded product gaps. No images/HTML, contributor
identities, credentials, photos or raw OCR enter this public dataset.

The original bulk OFF source and acquisition receipt remain unchanged. A separate
researched SQLite database adds information without rewriting their provenance.
Runtime reads only local verified stores: no paid service, provider scraping,
cloud database upload or new billing requirement. Source acquisition stays an
explicit maintenance step.

Research details are browseable factual information. They do not fabricate the
confirmed package observations required by claims/comparison or private sync.
Native camera/accuracy gates from the previous release remain separate.

## Component tracking

- Backend v0.10.0: researched SQLite, three GET APIs, source validation, packaging,
  local restoration and exported schemas. [Review](BACKEND_V0_10_0_REVIEW.md).
- Frontend v0.5.0+6: mixed source search and researched product detail screens,
  independent pagination/error handling and bounded public caches.
  [Review](FRONTEND_V0_5_0_REVIEW.md).

Local verification and production receipts are completed separately. The earlier
v0.9.0/v0.4.0 implementation and deployment evidence remain historical.
