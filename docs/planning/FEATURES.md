# Unlabel feature workflows

Status: planned core features. The foundation includes a minimal Flutter starter and manual GitHub build/release workflow; the four scanning/analysis features below are not implemented. Product name: **Unlabel**. Tagline: **Label Padhega India**.

One Flutter app directly in `frontend/` targets Android, iOS, and a responsive website. A scoped Dart offline evaluator and an expanded Python/FastAPI evaluator consume the same canonical declarative rules/IDs/versions. Website/API target separate later Vercel projects; `frontend/web/` is Flutter's platform folder. Local preferences add individual reasons. Gemini only improves wording. English/Hindi begin with reviewed content; Latin OCR is the first target and Devanagari requires separate validation.

Shared features live under `frontend/lib/features/`; platform camera/OCR/network/storage plus shared `analysis/` and `knowledge/` adapters live under `frontend/lib/core/`. Native OCR will use ML Kit; web OCR will use Tesseract.js through future JavaScript interop. Native live overlays are primary; web is capture-first. `UI_REQUIREMENTS.md` covers interface requirements. Offline supported rules have parity fixtures with Python, not separately authored source thresholds.

## 1. Evidence-based marketing claim checker

User goal: understand whether front-label claims are supported by the captured ingredient and nutrition information.

1. The scanner captures the front, then the back/side nutrition and ingredient panels within one session.
2. The user confirms that both captures are the same product, reviews recognized claims, and corrects important numbers/text.
3. The local parser/evaluator checks supported bundled claims; the shared backend can handle expanded rules online. Both link claims to required evidence, nutrition basis, and category.
4. An evaluator checks only criteria backed by a reviewed source with known applicability. It records input, rule/source version, and coverage; missing or unsupported criteria yield `insufficient_information`.
5. The analysis screen shows a claim state and a plain-language reason with the relevant package text/value and evidence link. Gemini can rephrase this fixed result without changing it.
6. The user may save the corrected scan, findings, and evidence to local history.

States are **supported by captured evidence**, **contradicted by captured evidence**, and **insufficient information**. These are informational findings, not legal certification or a regulator's enforcement decision. A title such as "Fake Healthy Claim Detector" does not justify accusing every unclear claim of fraud.

Examples to research and model include "High Protein," "No Added Sugar," and "Multigrain." Each needs its own inputs and applicable criteria. Total sugar alone cannot establish whether sugar was added; ingredient order alone cannot prove the percentage of whole grains. Missing quantities produce an unknown result.

Ownership: scanner supplies reviewed evidence; `core/analysis/` and backend parsing/analysis consume `knowledge/rules/claims/` within their supported coverage; analysis displays the result. No Gemini dependency is required. Offline coverage is a reviewed subset, not a full regulatory verdict.

Later validation: use representative supported, contradicted, category-mismatched, and incomplete examples. Changing a corrected value must invalidate the corresponding finding.

## 2. Live camera ingredient highlighting

User goal: notice relevant ingredient mentions quickly while viewing a package.

1. On Android/iOS, camera frames enter the native ML Kit OCR adapter at a controlled frequency; only one relevant processing request is active at a time. On the website, capture/select an image for a local Tesseract.js worker; enable box output explicitly.
2. Recognized text is matched to bundled ingredient/allergen aliases. Results retain bounding boxes and frame identity.
3. The scanner maps boxes into the visible preview, accounting for rotation, scaling, crop, and camera orientation. Old boxes disappear when the frame/product changes.
4. The preview marks relevant mentions with a short neutral label and a clear provisional state. Tap/capture opens the ingredient detail or review path.
5. After capture/correction, the supported local evaluator or online backend associates table values with nutrient names and evaluates reviewed numeric rules. Unsupported rules remain unknown.
6. The analysis screen becomes the durable result; a user can save it to client-local history. Live frames are not retained. Website live preview highlighting is progressive enhancement only after browser/device speed and memory measurements; unsupported capability is explained with the capture-first alternative.

Mention highlighting and nutrient-level assessment are different outputs. Seeing "salt" may highlight an ingredient; it does not prove the product is high in sodium. Numeric sugar/sodium/saturated-fat warnings require reliable values, units, a compatible basis, and applicable criteria. When evidence is missing, show the value or unknown state rather than a high-level warning.

This feature uses OCR boxes, not an AR model. It cannot detect chemicals through packaging or identify invisible ingredients. Blur, glare, curved wrappers, split words, multiple labels, and a changing preview can make recognition incomplete. Capture/review remains required before final conclusions.

Ownership: `core/camera/`, `core/ocr/`, scanner, generated knowledge bundles, and local/backend analysis. Live mention highlighting stays provisional; captured supported-rule results can work offline. Website OCR requires its worker/core/language assets to be available.

Later validation: test portrait/landscape alignment, stale-frame removal, dim lighting, readable Latin packaging, device latency, and graceful camera permission denial. Devanagari performance requires separate device evidence.

## 3. Personalized food suitability

User goal: see how a product's captured facts relate to selected dietary preferences and declared allergies.

1. The user selects vegetarian, high-protein, low-sodium, and/or known allergy preferences. These remain in phone-local or browser-local storage with no login, backend profile, or synchronization.
2. Local/online product evaluation is separate from preference mapping. Backend requests never include the preferences.
3. The evaluator produces neutral facts: declarations, canonical allergen/ingredient IDs, cross-contact statements, nutrient findings, evidence limitations, coverage, and policy/catalog versions.
4. A matching versioned policy on each client maps those facts to selected preference IDs and displays separate supported, conflicting, or unknown reasons.
5. The user can edit preferences and immediately re-evaluate existing neutral product facts locally; the original product findings and evidence remain intact.
6. Saved history stores the product analysis. Suitability is recomputed from current preferences when reopened; any persisted display snapshot must identify its preference/policy revision.

Preference mapping does not embed separate claim thresholds. It consumes versioned neutral facts from the scoped Dart evaluator or backend. `backend/app/services/personalization/` is reserved for the neutral reason catalog/policy payload, not profile processing or a user database.

Allergen handling must distinguish **declared ingredient**, **may contain/cross-contact statement**, **not detected in captured text**, and **unknown/incomplete information**. Not detected does not mean absent or safe. Unclear OCR, a missing ingredient panel, an unfamiliar alias, and an unsupported policy version must remain unknown. Users with allergies must check the full package and relevant professional advice; Unlabel cannot certify that a food is safe to consume.

Vegetarian suitability should use a readable declaration or adequately evidenced ingredient facts. An unreadable symbol is unknown. High-protein and low-sodium preferences are transparent product matches, not diagnoses, treatment plans, or individualized nutritional prescriptions.

Ownership: shared Flutter preferences, platform storage adapters, and analysis presentation; product detection/catalog comes from backend analysis/knowledge and `knowledge/rules/allergens/`. Gemini input always excludes preferences and allergy profiles. Shared Dart models/policy and fixtures keep Android/iOS/web mapping equivalent.

Later validation: the same neutral response must produce different, traceable reasons for different profiles. Missing allergen evidence must never produce an "allergen-free" or "safe" result. Profile changes must not generate a new cloud request.

## 4. Ingredient translator

User goal: understand technical ingredient/additive names in simple English or Hindi.

1. The user taps a recognized ingredient in the captured list or live preview.
2. The app resolves a canonical ID using the reviewed local glossary; the backend may provide a fuller cited entry when available.
3. Ingredient details show the original label term, common name, usual purpose, relevant evidence-backed considerations, and information gaps.
4. The user changes language; reviewed translations supply predictable wording. Optional Gemini wording uses only public ingredient facts and supplied evidence.
5. The entry links back to the current scan and its ingredient evidence. The saved scan retains canonical IDs and cited versions for later viewing.

Unfamiliar chemical names are not automatically marked dangerous. Purpose, permitted-use context, and a concern supported by evidence are distinct facts. An unknown name produces an unknown entry, not an invented explanation. Translation must not turn a qualified statement into an absolute risk or safety claim.

Hindi explanations do not require Hindi OCR for every package: Latin label text can resolve to a reviewed Hindi glossary entry. Devanagari label recognition is a separate capability to validate. If an entry has no reviewed Hindi content, show the available language and identify the missing translation.

Ownership: mobile/web ingredient-details features, localization adapters, generated knowledge bundles, `backend/app/services/knowledge/`, `knowledge/ingredients/`, and `knowledge/translations/`. Basic glossary lookup works without a backend or Gemini once client assets are available.

Later validation: common aliases resolve to one ingredient identity, unknown terms remain unknown, language switching preserves evidence, and explanations do not exaggerate concerns.

## Supporting features and sequencing

| Feature | Planned workflow and boundary | Priority |
| --- | --- | --- |
| Nutrition visualization | Render corrected, normalized values with visible units/basis; display missing values honestly and avoid unsupported health scores | Part of core analysis after parsing works |
| Local scan history | Explicit save/reopen/delete within that phone/browser store; no account/cloud sync; evidence versions visible; browser storage may be cleared/evicted | After one complete scan works |
| Product comparison | Select two saved analyses; align compatible bases, disclose missing values/category differences, and compare individual nutrients/reasons | Later supporting feature |
| Product enrichment | Optional public-barcode Open Food Facts lookup with provider provenance; package evidence remains primary | Later supporting feature |
| Legal Metrology checks | Research declaration requirements suggested by the supplied project background; add only reviewed, applicable checks | Later research scope, not MVP certification |
| Manual releases | Foundation workflow supports manual GitHub dispatch for APK and an unsigned IPA artifact; unsigned IPA is not directly installable on an iPhone, and final distribution depends on signing | Workflow foundation now; usable app later |

Comparison must not rank a product with missing values as healthier or silently compare one serving against 100 g. No universal health score is required for the mini-project.

## Modes shared by every feature

- **Online, Gemini disabled/unavailable:** expanded deterministic analysis with reviewed explanations; no paid AI plan is required.
- **Offline/backend unavailable:** local OCR, glossary, EN/HI templates, history, preferences, and bundled common nutrition/claim/allergen evidence checks remain available within declared coverage. Missing/unsupported rules yield `insufficient_information`; full regulatory coverage is not promised.
- **Offline website:** requires first successful load and explicit caching of app, worker/core/language, glossary, rules, and template assets through a planned service worker. Flutter's default web output does not supply that complete offline layer; first-visit offline use is not promised.
- **Demo mode:** clearly labeled bundled samples can explain the complete flow during a presentation; they must not be shown as live results for a newly scanned package.
- **Incomplete evidence:** show partial findings and specific missing inputs; neither Gemini nor an external product record may fill gaps silently.

Responsive iPhone/iPad portrait/landscape and MacBook website layouts, Android/iOS app layouts, light/dark appearance, keyboard/touch behavior, and permission/recovery flows are requirements. The starter demonstrates basic responsive foundation only; product colors remain undecided. Full feature development, deployment, and signed iOS distribution remain future work under the user's zero-cost/no-card constraint.
