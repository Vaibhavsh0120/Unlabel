# Unlabel feature workflows

The [20-group tracker](FEATURE_TRACKER.md) records backend readiness, frontend ownership and acceptance gates for the five concept screens. These broader workflows are separate from completed API capabilities.

Status: planned core features. The foundation includes a minimal Flutter starter and manual GitHub build/release workflow; the four scanning/analysis features below are not implemented. Product name: **Unlabel**. Tagline: **Label Padhega India**.

One Flutter app directly in `frontend/` targets Android/iOS/web. Backend v0.2.2 implements Open Food Facts product/nutrition lookup, source-tagged computed grades, confirmed-value normalization and separate catalogue status/lookup. Setup rebuilds local SQLite from the tracked public projection; the hosted build generates a verified immutable SQLite/receipt without network acquisition. [The current release review](BACKEND_V0_2_2_REVIEW.md) records actual hosted verification. Catalogue data is identity-only, coverage remains unverified, and a snapshot miss makes no OFF request. Nutrition charts and reviewed analysis remain frontend/later backend work. Reviewed FSSAI criteria, OCR, local preference matching and optional Gemini wording remain later versions; the MVP needs no Dart regulatory engine or evaluator-parity work. Website/API use separate configured Vercel projects; `frontend/web/` is Flutter's platform folder. See [URLs and deployment settings](VERCEL_SETUP.md).

Shared features and platform adapters live under `frontend/lib/features/` and `core/`. Reserved `core/analysis/` can manage result state/mapping, not an MVP legal-rule engine; `core/knowledge/` can serve an optional glossary. Native OCR will use ML Kit; web OCR will use future Tesseract.js interop. Native live overlays are later capability work; web is capture-first. English/Hindi use reviewed content; Devanagari recognition needs separate validation. See `UI_REQUIREMENTS.md`.

The first complete online slice is **barcode → Open Food Facts facts/insights → reviewed backend checks → clearly sourced report**. A sufficient provider record can produce a basic report without front/back OCR. Claims not recorded there need current front-label evidence; provider data alone cannot certify the package in the user's hand.

## 1. Evidence-based marketing claim checker

User goal: understand whether a stated front-label claim is supported by available product facts and reviewed criteria.

1. Barcode lookup loads Open Food Facts identity, facts, and separately labeled computed insights through the selected backend provider.
2. The user checks product identity and captures/types a front claim when needed. Back-panel OCR/correction is requested for missing facts or provider-package conflicts; paired captures must be the same product.
3. Backend parsing links the claim to source-tagged required facts, nutrition basis, category, and the current-package evidence that takes precedence after review.
4. The authoritative backend checks reviewed FSSAI criteria only where applicable. It records input/rule/source version; missing data, unresolved conflicts, or unsupported criteria yield `insufficient_information`.
5. The analysis screen shows a claim state and a plain-language reason with the relevant package text/value and evidence link. Gemini can rephrase this fixed result without changing it.
6. The user may save the corrected scan, findings, and evidence to local history.

States are **supported by available evidence**, **contradicted by available evidence**, and **insufficient information**, with visible provider/package origin. These are scoped informational checks, not full legal certification or a regulator's enforcement decision. "Fake Healthy Claim Detector" does not justify calling an unclear claim fraudulent.

Examples to research and model include "High Protein," "No Added Sugar," and "Multigrain." Each needs its own inputs and applicable criteria. Total sugar alone cannot establish whether sugar was added; ingredient order alone cannot prove the percentage of whole grains. Missing quantities produce an unknown result.

Ownership: selected `providers/products/` supplies primary data; scanner supplies conditional current-package evidence; backend parsing/analysis applies `knowledge/rules/claims/`; Flutter analysis displays the report. Gemini is optional. Fresh checks require an online backend; offline mode only reopens saved dated findings.

Later validation: use representative supported, contradicted, category-mismatched, and incomplete examples. Changing a corrected value must invalidate the corresponding finding.

## 2. Live camera ingredient highlighting

User goal: notice relevant ingredient mentions quickly while viewing a package.

1. On Android/iOS, camera frames enter the native ML Kit OCR adapter at a controlled frequency; only one relevant processing request is active at a time. On the website, capture/select an image for a local Tesseract.js worker; enable box output explicitly.
2. Recognized text is matched to bundled ingredient/allergen aliases. Results retain bounding boxes and frame identity.
3. The scanner maps boxes into the visible preview, accounting for rotation, scaling, crop, and camera orientation. Old boxes disappear when the frame/product changes.
4. The preview marks relevant mentions with a short neutral label and a clear provisional state. Tap/capture opens the ingredient detail or review path.
5. After capture/correction, the online backend associates values with nutrient names and reviewed numeric criteria, retaining any provider conflict. Unsupported rules remain unknown; no local numeric-rule engine is required.
6. The analysis screen becomes the durable result; a user can save it to client-local history. Live frames are not retained. Website live preview highlighting is progressive enhancement only after browser/device speed and memory measurements; unsupported capability is explained with the capture-first alternative.

Mention highlighting and nutrient-level assessment are different outputs. Seeing "salt" may highlight an ingredient; it does not prove the product is high in sodium. Numeric sugar/sodium/saturated-fat warnings require reliable values, units, a compatible basis, and applicable criteria. When evidence is missing, show the value or unknown state rather than a high-level warning.

This feature uses OCR boxes, not an AR model. It cannot detect chemicals through packaging or identify invisible ingredients. Blur, glare, curved wrappers, split words, multiple labels, and a changing preview can make recognition incomplete. Capture/review remains required before final conclusions.

Ownership: camera/OCR/scanner adapters and backend analysis. Live mention overlays remain provisional and are not required for the first barcode report. Fresh assessment is online; offline live scanning/OCR is not an MVP requirement. Website OCR needs available worker/core/language assets.

Later validation: test portrait/landscape alignment, stale-frame removal, dim lighting, readable Latin packaging, device latency, and graceful camera permission denial. Devanagari performance requires separate device evidence.

## 3. Personalized food suitability

User goal: see how a product's captured facts relate to selected dietary preferences and declared allergies.

1. The user selects vegetarian, high-protein, low-sodium, and/or known allergy preferences. These remain in phone-local or browser-local storage with no login, backend profile, or synchronization.
2. Online product evaluation is separate from local preference mapping; backend/Gemini requests never include profiles.
3. The backend produces neutral facts from source-tagged provider data and any current-package corrections: declarations, allergen/ingredient IDs, cross-contact, nutrient findings, limitations, and versions.
4. A matching versioned policy on each client maps those facts to selected preference IDs and displays separate supported, conflicting, or unknown reasons.
5. The user can edit local preferences. Completing an online report applies the current profile without transmitting it; changes do not alter previous product findings.
6. Saved history retains the dated report and suitability/profile snapshot. Offline viewing does not recompute fresh suitability; changed preferences are flagged and need an online report refresh before presenting new reasons.

The local preference mapper consumes backend-issued facts and contains no separate FSSAI thresholds. `backend/app/services/personalization/` is reserved for a neutral reason catalog/policy payload, not profile processing or a user database. Open Food Facts allergen tags are source information; incomplete provider/current-label evidence cannot establish absence.

Allergen handling must distinguish **declared ingredient**, **may contain/cross-contact statement**, **not detected in captured text**, and **unknown/incomplete information**. Not detected does not mean absent or safe. Unclear OCR, a missing ingredient panel, an unfamiliar alias, and an unsupported policy version must remain unknown. Users with allergies must check the full package and relevant professional advice; Unlabel cannot certify that a food is safe to consume.

Vegetarian suitability should use a readable declaration or adequately evidenced ingredient facts. An unreadable symbol is unknown. High-protein and low-sodium preferences are transparent product matches, not diagnoses, treatment plans, or individualized nutritional prescriptions.

Ownership: shared Flutter preferences, platform storage adapters, and analysis presentation; product detection/catalog comes from backend analysis/knowledge and `knowledge/rules/allergens/`. Gemini input always excludes preferences and allergy profiles. Shared Dart models/policy and fixtures keep Android/iOS/web mapping equivalent.

Later validation: the same neutral response can give different traceable reasons for local profiles; missing allergen evidence never gives "allergen-free"/"safe." Profiles never appear in requests. Offline preference editing must not silently update a saved suitability snapshot.

## 4. Ingredient translator

User goal: understand technical ingredient/additive names in simple English or Hindi.

1. The user taps an ingredient from Open Food Facts, a corrected package list, or the optional live preview; its origin remains visible.
2. The app resolves a canonical ID using the reviewed local glossary; the backend may provide a fuller cited entry when available.
3. Ingredient details show the original label term, common name, usual purpose, relevant evidence-backed considerations, and information gaps.
4. The user changes language; reviewed translations supply predictable wording. Optional Gemini wording uses only public ingredient facts and supplied evidence.
5. The entry links back to the current scan and its ingredient evidence. The saved scan retains canonical IDs and cited versions for later viewing.

Unfamiliar chemical names are not automatically marked dangerous. Purpose, permitted-use context, and a concern supported by evidence are distinct facts. An unknown name produces an unknown entry, not an invented explanation. Translation must not turn a qualified statement into an absolute risk or safety claim.

Hindi explanations do not require Hindi OCR for every package: Latin label text can resolve to a reviewed Hindi glossary entry. Devanagari label recognition is a separate capability to validate. If an entry has no reviewed Hindi content, show the available language and identify the missing translation.

Ownership: ingredient-details/localization, backend knowledge, `knowledge/ingredients/`, and `knowledge/translations/`. An optional preinstalled glossary and saved explanations can be read offline; fresh backend lookup/Gemini wording requires online access.

Later validation: common aliases resolve to one ingredient identity, unknown terms remain unknown, language switching preserves evidence, and explanations do not exaggerate concerns.

## Supporting features and sequencing

| Feature | Planned workflow and boundary | Priority |
| --- | --- | --- |
| Nutrition visualization | Render primary provider/corrected values with units/basis; distinguish provider-computed scores from Unlabel criteria; keep missing values unknown | First online report |
| Local scan history | Explicit save/reopen/delete; dates/origins/versions/profile snapshot visible; offline read-only findings; no sync and browser eviction possible | Small optional offline feature |
| Product comparison | Select two saved analyses; align compatible bases, disclose missing values/category differences, and compare individual nutrients/reasons | Later supporting feature |
| Primary product provider | Selected Open Food Facts barcode lookup through backend with computed insights, provenance, completeness, and current-package conflict review | First online slice |
| Legal Metrology checks | Research declaration requirements suggested by the supplied project background; add only reviewed, applicable checks | Later research scope, not MVP certification |
| Manual releases | Foundation workflow supports manual GitHub dispatch for APK and an unsigned IPA artifact; unsigned IPA is not directly installable on an iPhone, and final distribution depends on signing | Workflow foundation now; usable app later |

Comparison must not rank a product with missing values as healthier or silently compare one serving against 100 g. No universal health score is required for the mini-project.

## Modes shared by every feature

- **Online, Gemini unavailable:** primary provider data/insights plus reviewed backend checks/templates; no paid AI plan is required. Missing provider facts stay unknown or request targeted label evidence.
- **Offline/backend unavailable:** view saved dated reports, edit preferences, and optionally read a preinstalled glossary. No new analysis, uncached Open Food Facts lookup, or Gemini call; no offline regulatory engine required.
- **Optional offline website:** earlier successful load and explicit app/history/glossary caching are needed. Flutter's default output supplies no complete offline layer; no first-visit offline or mandatory offline OCR promise.
- **Demo mode:** clearly labeled bundled samples can explain the complete flow during a presentation; they must not be shown as live results for a newly scanned package.
- **Incomplete evidence:** show partial findings and specific missing inputs; neither Gemini nor an external product record may fill gaps silently.

Responsive iPhone/iPad portrait/landscape and MacBook website layouts, Android/iOS app layouts, light/dark appearance, keyboard/touch behavior, and permission/recovery flows are requirements. The starter demonstrates basic responsive foundation only; product colors remain undecided. Full feature development, deployment, and signed iOS distribution remain future work under the user's zero-cost/no-card constraint.
