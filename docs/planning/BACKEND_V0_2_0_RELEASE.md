# Backend v0.2.0

Unlabel can now fetch nutrition tables and normalize user-confirmed nutrient rows. This backend release preserves the strict v0.1.0 product response. **Frontend remains v0.0.0; APK/unsigned IPA artifacts are unchanged.**

## Added

- `GET /v1/products/{barcode}/nutrition`: bounded OFF v3.6 direct input tables, original rows, units, table/preparation/source identity, unknown reasons and licensed attribution.
- `POST /v1/nutrition/normalize`: confirmed public label rows, random request/session IDs and revision correlation; no OFF dependency, uploads or persistence.
- kcal/kJ and g/mg/ug conversions; compatible per-100 g or per-100 mL views; unknown serving quantities stay per serving. Salt/sodium, total/added sugars and available/total carbohydrate remain distinct.
- Duplicate conflicts and disagreeing comparable OFF tables request review. Computed/estimated/qualified upstream values are excluded from exact facts; original tables are retained.
- Strict numeric/confirmation/privacy validation, actual 32 KiB body cap, at most 64 accepted rows, 16 upstream tables and 32 returned validation errors. Unsupported precision cannot silently become zero.
- Separate nutrition schemas/examples, v0.2.0 OpenAPI and a reproducible contract export tool. Historical product schema/OpenAPI remain intact.

## Validation

120 pytest cases pass; Ruff checks/format and dependency consistency pass. Source review findings were fixed with regression tests. Live OFF nutrition retrieval was verified before implementing against it; a real local HTTP smoke also exercised the new routes. One existing Starlette/HTTPX TestClient deprecation warning remains recorded. See [full review](BACKEND_V0_2_0_REVIEW.md).

Production backend v0.2.0 and the unchanged Flutter starter passed public HTTPS checks after automatic Git deployment. Health/meta/OpenAPI, confirmed POST, live OFF nutrition/product reads, CORS and invalid/oversized input checks passed. The [review](BACKEND_V0_2_0_REVIEW.md) records the source SHA and both READY deployments before the final documentation push. GitHub records final tag/publication state. Public destinations: [Backend API](https://unlabel-api.vercel.app/v1/meta), [API docs](https://unlabel-api.vercel.app/docs), [Flutter starter website](https://unlabel-india.vercel.app).

## Limits and next version

Normalization is factual arithmetic, not a food-quality score, allergy decision or FSSAI compliance verdict. `complete` means submitted rows normalized successfully, not that all nutrients were reported or the food is safe. Rounded/conflicting declarations may require correction; no tolerance or density is guessed. No package photos, OCR, AI key, model training, database import or frontend features were added.

The India-filtered search returned 503 in the bounded check. Official global exports are documented, but a dedicated India export, corpus size/completeness and Vercel storage fit are unverified. **v0.2.1** is the separate India snapshot feasibility/import milestone, with the agreed manual six-month replacement policy. FSSAI claim checks remain later work.
