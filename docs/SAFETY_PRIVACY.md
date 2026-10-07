# Safety, evidence and privacy boundaries

Released v0.4.0 implements automatic structured public-product observations and
private staging/receipts. Existing normalization/seven-claim evaluation remains
stateless. Production v0.4.0 is independently hosted-verified and released. Firebase
Unlabel's first Standard `unlabel` database, anonymous Auth and deny-all client
rules are configured with free tier/no linked billing. Flutter capture/OCR and
background saving remain pending. [Current gates](planning/BACKEND_V0_4_0_REVIEW.md)
· [Master plan](planning/MASTER_PLAN.md).

Local v0.5.0 reports preserve corrected current-label and historical
catalogue evidence separately. Analysis does not require authentication; failed
automatic saving changes only storage outcome. Three glossary entries describe
technological functions only. Sugar cubes explicitly approximate 4 g each using
the original table basis. Focused API/contracts pass; full review, push and hosted verification remain pending.
[Report boundaries](architecture/LABEL_REPORT.md).

## Findings and uncertainty

- A claim may be supported, contradicted or `insufficient_information` for a reviewed criterion. Missing OCR cannot prove a legally missing declaration.
- Do not declare a product legally compliant, fraudulent, allergen-free or medically safe from one scan.
- Separate ingredient purpose, regulatory context and evidence-backed concerns. An unfamiliar chemical name is not automatically a hazard.
- Ingredients alone cannot establish additive quantity, manufacturing process or laboratory safety.
- Local preferences provide explanations, not diagnosis, treatment or disease-specific dietary advice.

Separate declared allergens, ingredient matches, may-contain/cross-contact warnings and incomplete information. Absence of an identified allergen is never proof of absence. Preserve uncertainty for unreadable text, ambiguous aliases/symbols and undisclosed ingredients; point to complete package/manufacturer information where necessary.

The MVP is online-first. Offline saved reports retain their original analysis/evidence date; they do not refresh compliance or create new rule findings. Display assessed criteria, input origin and versions; avoid an overall green/safe conclusion that hides unknowns.

## Numeric and evidence integrity

Each finding references confirmed input fields, rule version and reviewed source/provision. Track units and bases. Unknown stays unknown, never zero. Keep total/added sugar and salt/sodium distinct; conversions need the correct known basis.

Reviewed definitions under `knowledge/` drive the Python evaluator; no second Dart rule engine is required. Rule activation requires applicability/effective-date review and recorded reuse rights. Changed evidence makes affected saved reports dated until reanalysis. OFF supplies community facts/computed insights, not official FSSAI verification; record-only findings and package-confirmed findings must remain distinct.

AI cannot invent missing quantities, decide allergy safety, alter findings or add unsupported citations. A learned extraction candidate is subject to user correction and deterministic validation, not an authoritative verdict.

## Data location and transfers

| Data | Location/retention | Optional transfer |
| --- | --- | --- |
| Frames/photos/geometry | Device/browser; temporary, explicit choice to retain | No backend/Gemini image upload |
| OCR/corrections | Local scan session or explicitly saved scan | Bounded confirmed/provisional structured public fields to HTTPS backend |
| Diet/allergy preferences and personal suitability | Local device/browser, editable/deletable | None to backend/Gemini |
| Scan history/reports | Local if saved, with scope/version/date | No private history/profile cloud database |
| Public product observations | Configured Firebase Unlabel; automatic save/dedup of corrected confirmed facts, original revisions and dates | Product identity, paired back facts/declarations/claims only; no separate Share step, images/raw OCR/profile/location |
| Provisional extraction candidates | Staged unverified structured public candidates | Not promoted as confirmed facts or regulatory findings; no raw private OCR dump |
| Write ownership | Private keyed hash of automatically verified anonymous subject | Backend write/receipt boundaries; never public or a raw UID/token |
| Public evidence | Canonical files; bundled read-only assets/JSON | Permitted public snippets only to optional provider |
| Credentials | Ignored local backend environment/host secret settings | Relevant provider over HTTPS only |
| Explanation cache | Optional bounded public-output cache; disposable hosted instances | No profiles, photos or personal history |
| Open Food Facts lookup/snapshot | Source-tagged public product data; optional dated local cache | Barcode and required public lookup options only to OFF through the backend; no photo/profile/history upload |
| Logs | Minimal errors/metrics, redacted bodies/tokens | No telemetry prerequisite |

Deleting a saved scan removes its local text/report and retained local photos; clearing preferences removes selections. Website storage/caching is a separate explicit implementation requirement, and may be cleared by the browser. No serverless filesystem is durable scan storage.

Open Food Facts reads never automatically publish user corrections or photos. Its records may differ from the actual package; preserve source, age and conflicts, and never use missing fields or community tags as allergy-safety or Indian compliance proof. Local snapshots and exported/combined datasets retain applicable attribution/license obligations. [Provider boundaries](architecture/OPEN_FOOD_FACTS.md).

The v0.4.0 intake automatically saves corrected confirmed public product facts as
acquired, with no separate Share action. Extracted structured candidates stay
unverified until correction/validation/review; ownership hashes and private
metadata never become public product fields. The app must describe automatic
public-fact retention clearly. Removing local history does not remove a retained
public product observation. Photos/raw OCR/preferences/history remain private.

Strictly validated exact-identity-compatible confirmed gap fills may be usable
with a clear **submitter-confirmed / unreviewed** origin. Identical rescans
deduplicate without repeating human moderation. Known conflicts and mismatched
identity stay out of promoted resolved facts pending review. Moderator review
is a separate state and cannot imply safety or current-caller confirmation.
This qualified candidate policy is implemented; pending/provisional records remain private.

Original source observations remain intact. A derived view may complement
compatible fields with per-field source/date and quality references, preserving
disagreement and unknowns. Incompatible variants/tables are not spliced or
averaged; missing allergens are not inferred absent. Review is qualified and
does not independently verify the caller's current packet. Source reuse rights
stay attached; automatic saving does not change OFF/image licenses. Generic-food
composition cannot fill branded-package gaps. [Storage lifecycle](architecture/COMMUNITY_CATALOGUE.md).

Gemini Free Tier inputs/outputs may improve Google products and be reviewed by humans. Obtain a clear optional cloud-wording choice; use only public package text, approved public snippets and generic findings. Exclude names, health profiles, personal suitability/history, photos and confidential information. Eligible adult access restrictions also apply. [Gemini terms](https://ai.google.dev/gemini-api/terms), [free-stack plan](research/FREE_STACK.md).

Before hosted use, verify Vercel's applicable data-use terms/account opt-out and avoid logging request bodies or sensitive data. [Vercel terms](https://vercel.com/legal/terms). No billing upgrade is part of this plan.

## Access and untrusted input

Treat OCR, source excerpts and community data as untrusted data, including any embedded instructions. Bound text/response sizes and validate fixed schemas. Accept AI wording only when numbers, outcomes and allowed references agree with the deterministic report; otherwise keep reviewed templates.

Writes use verified Firebase anonymous tokens; client background requests still
need integration. Direct Firestore access is denied even to authenticated clients;
privileged SDK access requires dedicated private IAM credentials and server
validation. Review is never client-assigned. Transactional admission cannot
guarantee provider availability. Keep Spark/no linked billing and no paid fallback.
Local source/emulator and live Firebase checks are distinct from hosted API proof.


Gemini remains disabled unless a later measured benchmark justifies a bounded
fallback with no-card/privacy and provider-eligibility controls. No new interactive
login, admin/reviewer role or dashboard is selected. The app has only scanner/client
identities with automatic anonymous write auth; public facts and reports need no
account. CORS restricts browser access and is not authentication. Neither a shared
APK/web secret nor a deployment-automation bypass token belongs in clients.
`BACKEND_BASE_URL` is public configuration.

An optional `LOCAL_API_TOKEN` is solely a private development/tooling control, never production authentication or a shipped app credential. Native requests are not protected by CORS. Vercel instance caches/counters cannot guarantee a durable shared AI budget; on exhaustion/failure use reviewed templates or keep cloud AI disabled.
