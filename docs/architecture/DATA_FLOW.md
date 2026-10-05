# Unlabel data flow and ownership

Status: planned feature architecture. The minimal Flutter starter and manual build/release workflow are foundation work; barcode lookup, OCR, backend analysis, report storage, and AI connections below are not implemented.

One Flutter app directly in `frontend/` targets Android, iOS, and the responsive website; `frontend/web/` is its web platform directory. Open Food Facts is the primary online source of barcode product facts and source-tagged computed insights. FastAPI normalizes those facts and applies reviewed FSSAI criteria. OCR fills gaps, captures front claims, and resolves differences from the current package. Later website/API are separate Vercel projects. Local preferences map backend-issued neutral facts to individual reasons; Gemini optionally improves wording.

## End-to-end online lookup and label review

```mermaid
flowchart TD
    A[Scan or enter package barcode] --> D[Shared backend product endpoint]
    D --> O[Open Food Facts online lookup]
    O --> C[Source-tagged product facts and computed insights]
    C --> R[Check product identity and review relevant fields]
    P1[Optional current-package front and back capture] --> B[Native ML Kit or browser Tesseract OCR]
    B --> R
    R --> E[Backend normalization and conflict resolution]
    K[Reviewed knowledge JSON and CSV] --> S[Read-only bundled knowledge]
    S --> F[Deterministic product rules and evidence]
    E --> F
    F --> G[Reviewed English and Hindi explanation templates]
    F -. optional public facts only .-> H[Gemini explanation provider]
    H --> I[Validate explanation against fixed findings]
    G --> J[Neutral analysis response]
    I --> J
    J --> L[Client maps neutral facts to local preferences]
    P[Local allergy and diet preferences] --> L
    L --> M[Result and ingredient detail views]
    M --> N[Explicit dated report save on phone or browser]
    N --> Q[Offline read-only saved report]
```

1. `frontend/lib/features/scanner/` offers barcode camera scanning or manual entry. `core/network/` calls `GET /v1/products/{barcode}`; `backend/app/providers/products/` performs the selected Open Food Facts lookup online.
2. The backend returns available identity, ingredient/nutrition/declaration facts and computed insights, tagged with provider, retrieval time, product revision where available, and completeness. Missing fields stay missing. Provider-computed scores/tags are separate from Unlabel's FSSAI checks.
3. The user checks identity and relevant fields against the package. A basic product report need not require front/back OCR if provider data is sufficient; it is explicitly based on the provider record, not proof that every current-package declaration was checked.
4. Optional capture supplies front claims, missing ingredient/nutrition panels, or conflict evidence. `core/camera/` keeps images local; `core/ocr/` later adapts native ML Kit and browser Tesseract.js through one interface. Web is capture/file-first; native live boxes are provisional. Mobile-only plugin imports cannot reach web code.
5. `features/scanner/data/` links barcode facts, original/corrected OCR, capture side, boxes, and completeness into one draft. The user confirms front/back belong to the same product. Current-package evidence takes precedence after review; confirming provider text does not erase its provider provenance.
6. `core/network/` submits the barcode/source snapshot and any confirmed public corrections/claims for online analysis. It excludes photos, preference profiles, history, identifiers, and unrelated contact text. The backend validates inputs and re-resolves provider facts when necessary; client-supplied classifications are not trusted rule results. Planned contracts live in `contracts/schemas/` and `contracts/examples/`.
7. Backend parsing/analysis normalizes units, resolves conflicts, and applies reviewed category-aware FSSAI criteria. `services/knowledge/` resolves aliases/evidence from canonical knowledge. Missing inputs, unsupported criteria, or unresolved contradictions yield `insufficient_information`. There is no required Dart legal/nutrition evaluator or Python/Dart rule-parity implementation in the MVP.
8. `backend/app/services/personalization/` is reserved for a neutral product-fact and suitability-reason catalog/policy payload. It does not receive or store user profiles. The response identifies declared allergens, cross-contact statements, dietary declarations, nutritional findings, and evidence limitations.
9. `backend/app/providers/ai/` may rephrase selected public facts and fixed findings using `backend/app/prompts/`. Its input excludes preferences, raw images, scan history, and personal identifiers. `backend/app/schemas/` validates output; conflicting, missing, or unsupported statements trigger template fallback.
10. Shared `features/preferences/` maps backend-issued neutral facts to local preference IDs while completing an online report. This small mapper does not reproduce FSSAI thresholds. Analysis presents provider insights, Unlabel checks, personal reasons, dates, and limitations separately.
11. `features/history/` explicitly saves the report through `core/storage/`, including selected source facts/corrections, findings, evidence/rule versions, dates, and the suitability snapshot/profile revision. Offline viewing preserves those dated findings rather than running fresh analysis. Phone/browser stores are separate; no automatic synchronization is planned.

## Where the knowledge originates

Open Food Facts supplies primary runtime product data and existing computed insights. Regulatory knowledge is maintained separately: FSSAI rules, relevant Legal Metrology material, ingredient references, and provider documentation are reviewed before encoding. A regulator document is not assumed to provide an OCR/product API; Open Food Facts computed classifications do not certify FSSAI compliance.

| Location | Planned responsibility |
| --- | --- |
| `knowledge/sources/registry/` | Source URLs, issuing bodies, document titles, effective/retrieval dates, licensing notes, and review status |
| `knowledge/sources/downloads/` | Local reference downloads where storage and redistribution are permitted; not live runtime queries |
| `knowledge/rules/claims/` | Reviewed claim criteria, category/basis applicability, required inputs, and source references |
| `knowledge/rules/nutrition/` | Reviewed nutrient normalization/classification policies and applicability |
| `knowledge/rules/allergens/` | Canonical allergen IDs, ingredient aliases, cross-contact handling, and conservative evidence states |
| `knowledge/ingredients/` | Ingredient/additive identities, purposes, aliases, and bounded evidence summaries |
| `knowledge/translations/en/`, `knowledge/translations/hi/` | Reviewed language templates and glossary entries |
| `frontend/assets/knowledge/` | Optional preinstalled glossary/EN-HI text and lightweight preference catalog; no required offline regulatory-rule bundle |
| `backend/storage/runtime/` | Optional local-only derived SQLite index; ignored and rebuildable; hosted API must not depend on it |

Versioned JSON/CSV is canonical for the backend's reviewed rules and references. Validation later emits a read-only backend knowledge bundle; SQLite is an optional local derived index, not a writable Vercel database. Hosted requests use immutable knowledge/request memory, with no persistent shared filesystem/cache or global in-memory quota assumed. Downloads never become trusted rules automatically. No vector database, embeddings, live scraping, or full RAG pipeline is required for the MVP.

Open Food Facts is the selected primary product-data provider under `backend/app/providers/products/`. Its barcode facts and computed insights reduce bespoke data/model work. Each field keeps provenance, available revision, and freshness; scores retain their provider/algorithm identity where available. Conflicting records cannot silently replace the current package. With a missing record or provider failure, an online backend may analyze sufficient user-confirmed label evidence instead. Offline use is limited to saved reports/preferences and an optional preinstalled glossary. [Complete provider workflow](OPEN_FOOD_FACTS.md).

## Normalization and evidence boundary

- Preserve per-serving, per-100 g, and per-100 mL bases separately. Compare only compatible bases; require serving quantity for conversion.
- Preserve units and distinguish sodium from salt, total sugar from added sugar, and kcal from kJ. Do not convert mass to volume without an evidenced density.
- Missing is not zero. Decimal separators, OCR substitutions, table-column ambiguity, and implausible values require correction or an unknown state.
- Ingredient order alone does not reveal exact nutrient amounts. Ingredient text cannot establish a numeric "high sodium" or "high sugar" classification.
- Every finding references its input fields, rule ID/version, category, evidence source, and applicable date. A current regulation may not apply to every historical package.
- A correction creates a new scan revision and invalidates findings derived from the changed input. Historical findings retain their original versions until the user requests reanalysis.
- Provider insights and backend criteria have distinct origins. A provider score is not an Indian legal verdict; reviewed FSSAI checks cover only implemented, applicable criteria with sufficient evidence, not full legal compliance.
- Gemini output is optional wording. It cannot invent evidence, override rule states, classify unknown allergies as safe, or provide treatment advice.

## Storage and lifecycle

| Data | Origin and processing | Final location and retention |
| --- | --- | --- |
| Package photos/live frames | Phone/browser camera or selected file; local OCR | Frames discarded after use; in-app photos temporary unless explicitly saved; original selected files remain user-owned |
| OCR draft and corrections | Client OCR and user | Client draft until completion/deletion; included in saved history only when requested |
| Analysis request | Barcode/provider snapshot plus relevant confirmed public corrections/claims | Backend request memory; no default scan database or raw-content logs |
| Neutral findings and citations | Source-tagged provider insights plus authoritative backend checks | Saved on client with origin/date/version; backend discards request state after completion |
| Preferences/allergies | User on client | Phone/browser-local profile; editable/deletable; never sent to backend or Gemini |
| Saved analyses | Explicit client save action | Phone/browser-local dated reports until deleted/cleared/evicted; offline read-only findings; no cloud sync |
| Curated knowledge | Reviewed public references | Versioned canonical repository files; derived local bundles/indexes are rebuildable |
| Gemini request | Allowlisted public facts and evidence summaries | Optional external processing under the provider's current terms; no Unlabel server archive |
| Primary product facts/insights | Selected Open Food Facts online barcode lookup | Provider-tagged response and explicitly saved report; no persistent shared hosted cache required |

Later mobile storage uses app-private storage and a small local database; web history uses browser-local IndexedDB behind an adapter. Final storage packages are later choices. Browser private mode, origin changes, eviction, and clearing site data can lose browser history; browsers are not a guaranteed backup. `data/private/` is ignored development data, not a production upload target. `data/fixtures/` holds owned/permitted, non-personal examples only.

## Failures and recovery

| Condition | Planned behavior |
| --- | --- |
| Backend reachable, Gemini unavailable | Backend checks and reviewed EN/HI templates remain available for sufficient provider/package facts; identify explanation mode |
| Gemini invalid or contradictory output | Discard generated wording and show templates for the same findings |
| Offline/backend unavailable | Read saved dated reports, edit local preferences, and use any preinstalled glossary; no fresh product analysis, uncached lookup, or Gemini call |
| OCR assets unavailable | Basic barcode report can proceed when provider facts are sufficient; missing claims/conflict evidence stays unknown or awaits manual correction |
| Website camera unsupported/denied | Offer supported image selection and correction/manual entry; keep permissions actionable and stop camera tracks when leaving capture |
| Poor OCR or missing back label | Request only evidence needed by the relevant check; sufficient provider-based findings may still be shown with their origin |
| Open Food Facts lookup fails | State missing/unreachable record; optional label evidence can support online backend checks, with no invented provider insight |
| Request interrupted | Preserve local draft for retry; do not save a successful result or mix responses from different revisions |
| Saved report or preference snapshot is old | Show analysis/source dates and earlier profile revision; request online refresh for new findings/suitability, never silently relabel stored results as current |

New analysis is online-first and needs the API within free limits; laptop/LAN remains a demo alternative. Website camera requires a secure context. Optional offline web history/glossary needs an earlier successful load and explicit app/asset caching; Flutter supplies no default complete offline layer. First-visit offline use, OCR asset caching, and a local regulatory engine are not MVP promises. Origin allowlists, provider/request limits, abuse controls, and server-only keys are future tasks.

## Validation planned for implementation

Fixtures will cover barcode success/missing records, source/algorithm tagging, provider-package conflicts, conditional OCR, normalization, incomplete evidence, reviewed backend criteria, and saved-report dates. Platform adapters share models; device checks measure boxes/browser OCR. Offline checks prove saved data is readable without starting new analysis/provider/AI calls. Starter builds prove neither scanning nor regulatory/provider behavior.
