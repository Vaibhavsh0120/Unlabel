# One product information destination

`frontend/lib/features/scanner/presentation/product_info_page.dart` owns
`ProductInfoPage`, the destination for scanning, catalogue search, research
matches, history and saved products. Its report/research/extracted/barcode
constructors select private content widgets, with one page title and navigation
shell. The 26 October update implements the supplied reference hierarchy with
smaller phone typography, fact-count summary, evidence cards, six nutrient tiles,
ingredient/allergen tabs, unknowns and source disclosures. It supersedes the
earlier deferred visual redesign. See [current frontend review](../planning/FRONTEND_V0_11_0_REVIEW.md).

Source-specific facts remain distinct. A dated catalogue snapshot is not a
current-package check; a model reading is not human-confirmed. Original source
sections, nutrition bases, claims, allergens, ingredient explanations and sugar
approximations retain the existing report contracts. Missing fields remain unknown.

Front/back extraction searches both indexed catalogues by the read name. The
person selects a matching brand, variant and pack size; the app does not choose
an arbitrary first result. Barcode-only capture opens a known report/research
record or an unknown-product view that can request optional live sources.

Public machine readings are separate additions with provider/date and explicit
conflict information. Their creation belongs to the backend's validated automatic
admission path, never a client-created confirmed draft.

NutriGraph data is an optional session-only section. It is requested for a selected
barcode, has no client cache or save serializer, and is discarded at provider
expiry, page disposal or an expired lifecycle resume. Its absence never removes
local facts. The backend key and quota are independent of the user's account;
the provider is disabled until configured. Product-name search is not forwarded
to NutriGraph. See [AI routing](AI_ROUTING.md) and the
[backend review](../planning/BACKEND_V0_14_0_REVIEW.md).

Photographed front claims travel with the explicit candidate selection. The
read-only `POST /v1/claims/catalogue-check` sends the selected barcode and claim
text, never uploaded nutrition or a fabricated confirmation flag. The backend
compares exact sourced numbers with reviewed criteria. Product category/form and
current-package context remain unknown, so the overall claim remains insufficient;
numeric comparisons and original source/table references are visible separately.
