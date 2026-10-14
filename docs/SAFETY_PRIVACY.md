# Safety, evidence and privacy boundaries

Current source versions come from [frontend pubspec](../frontend/pubspec.yaml)
and [backend pyproject](../backend/pyproject.toml). The new auth/profile scope and
private account deletion have separate [frontend](planning/FRONTEND_V0_9_0_REVIEW.md)
and [backend](planning/BACKEND_V0_13_0_REVIEW.md) reviews. Final exact-source hosted/native
verification is pending. Earlier read-only backend checks exclude authenticated
extraction/staging; physical-device accuracy remains separate.

Confirmed current-label and historical source facts retain distinct evidence.
Analysis needs no account; automatic storage failures change only their separate
outcome. Six reviewed glossary entries describe technological functions, not
health/allergy/Indian-permission verdicts. Sugar cubes approximate **4 g each**
on the original table basis. No universal safety score is implemented.

Guests keep personal records locally. Optional Google/password accounts use
isolated UID-specific libraries and bounded private display-name/saved/history sync.
Linking another sign-in method preserves that UID; collisions never merge libraries.
Cloud/device differences require explicit choices; CAS revisions and immutable
mutation IDs preserve safe retries/deletion. Sign-out returns to guest data.
Package photos, raw OCR, geometry, dietary/allergen reminders, appearance, Welcome
completion and Insight bookmarks remain outside library sync. A separately selected
profile photo saves only its cropped thumbnail privately; original photos/EXIF are
not retained. Optional gender controls a default avatar and is never inferred from
Google or a photo. Unset gender uses the approved male avatar without recording a
gender choice. [Account/profile storage](architecture/ACCOUNT_PROFILE.md). Insight bookmarks
are device-wide educational data, outside scanner identity namespaces.
[Private sync](architecture/PRIVATE_ACCOUNT_SYNC.md) ·
[Insights](architecture/INSIGHTS.md).

The configured Standard Firestore `unlabel` database stays on the free tier
without linked billing, with anonymous/password/Google Auth. Direct access is
denied to public facts, private libraries and machine collections. The sole client
exception is strict owner-only `profile_media/{uid}`; anonymous users, other owners,
collection listing and other databases are denied. These stores have
independent admission. Earlier v0.4/v0.5/v0.7 backend and v0.1/v0.2/v0.3 frontend
release evidence remains in its dated reviews; it does not establish current
hosted or native behavior. [Master plan](planning/MASTER_PLAN.md).

## Findings and uncertainty

- A claim may be supported, contradicted or `insufficient_information` for a reviewed criterion. Missing OCR cannot prove a legally missing declaration.
- Do not declare a product legally compliant, fraudulent, allergen-free or medically safe from one scan.
- Separate ingredient purpose, regulatory context and evidence-backed concerns. An unfamiliar chemical name is not automatically a hazard.
- Ingredients alone cannot establish additive quantity, manufacturing process or laboratory safety.
- Local dietary/allergen choices are reminders; automatic personal suitability is unfinished and no diagnosis, treatment or disease-specific advice follows from them.

Separate declared allergens, ingredient matches, may-contain/cross-contact warnings and incomplete information. Absence of an identified allergen is never proof of absence. Preserve uncertainty for unreadable text, ambiguous aliases/symbols and undisclosed ingredients; point to complete package/manufacturer information where necessary.

The MVP is online-first. Offline saved reports retain their original analysis/evidence date; they do not refresh compliance or create new rule findings. Display assessed criteria, input origin and versions; avoid an overall green/safe conclusion that hides unknowns.

## Numeric and evidence integrity

Each finding references confirmed input fields, rule version and reviewed source/provision. Track units and bases. Unknown stays unknown, never zero. Keep total/added sugar and salt/sodium distinct; conversions need the correct known basis.

Reviewed definitions under `knowledge/` drive the Python evaluator; no second Dart rule engine is required. Rule activation requires applicability/effective-date review and recorded reuse rights. Changed evidence makes affected saved reports dated until reanalysis. OFF supplies community facts/computed insights, not official FSSAI verification; record-only findings and package-confirmed findings must remain distinct.

AI cannot invent missing quantities, decide allergy safety, alter findings or add unsupported citations. A learned extraction candidate is subject to user correction and deterministic validation, not an authoritative verdict.

## Data location and transfers

| Data | Location/retention | Optional transfer |
| --- | --- | --- |
| Frames/photos/geometry | Temporary device/browser capture session; no durable photo store | With explicit consent, bounded PNG/JPEG photos go to backend and its globally active Gemini/OpenAI provider for reading; geometry is returned to the current session |
| Raw OCR/corrections | Raw OCR stays in the local capture session; only structured corrected facts enter saved reports | Bounded confirmed/provisional structured public fields to HTTPS backend |
| Diet/allergy reminders | Local device/browser, editable/deletable; no suitability verdict | None to backend/AI providers |
| Scan history/reports | Guests device/browser-local; Google/password account uses its isolated local namespace and bounded private snapshot | Optional login enables private caller-owned CAS sync; counts 50 saved/100 history, data 384 KiB; no silent trimming |
| Account display name | Firebase Auth SDK profile plus bounded account-library display name | Google supplies SDK name/photo; the library payload contains no email/UID/password/token fields |
| Profile avatar and optional gender | Owner-only `profile_media/{uid}` in named `unlabel` Firestore; guests keep only gender/default selection locally | Explicit gallery crop saves a 192×192 PNG of at most 96 KiB, source choice and optional gender; no original/EXIF, public observation or AI transfer |
| Appearance/Welcome completion and Insight bookmarks | Device/browser-local | Never part of private cloud snapshot |
| Public product observations | Configured Firebase Unlabel; automatic save/dedup of corrected confirmed facts, original revisions and dates | Product identity, paired back facts/declarations/claims only; no separate Share step, images/raw OCR/profile/location |
| Unverified AI structured proposals | Backend-only private Firestore staging; 256 buckets × eight items × 32 KiB facts, opportunistic seven-day expiry and oldest-item eviction | Literal extracted identity/claims/ingredient/declaration/nutrient fields only, with hashed ownership; no photos, raw OCR, region text/geometry, prompts or provider envelopes |
| Provisional extraction candidates | Staged unverified structured public candidates | Not promoted as confirmed facts or regulatory findings; no raw private OCR dump |
| Write ownership | Private keyed hash of verified anonymous/password/Google scanner subject | Backend write/receipt boundaries; never public or a raw UID/token |
| Public evidence | Canonical reviewed files and receipt-verified read-only knowledge | Deterministic criteria are not transferred through an explanation-provider route |
| Credentials | Ignored local backend environment/host secret settings | Relevant provider over HTTPS only |
| Open Food Facts lookup/snapshot | Source-tagged public product data; optional dated local cache | Barcode and required public lookup options only to OFF through the backend; no photo/profile/history upload |
| Logs | Minimal errors/metrics, redacted bodies/tokens | No telemetry prerequisite |

Deleting a guest saved report removes its local copy. Signed-in saved/history/display-name changes sync a bounded private snapshot; Clear account library sends a versioned empty library snapshot, and failed deletion stays pending locally. This action retains the Firebase sign-in profile, avatar and gender; photo options remove a custom thumbnail separately. Guest copies and public observations remain separate. Captured photo retention is not implemented. Clearing local appearance/preferences removes device selections. Website local storage is implemented, and may be cleared/evicted by the browser; complete offline app caching/restart remains a separate verification gate. No serverless filesystem is durable scan storage.

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

Backend v0.11 adds optional package-photo reading, authorized by the user on
8 October 2026. Obtain explicit transfer consent before sending package photos
to the backend and its globally configured Gemini/OpenAI service. Gemini Free
Tier inputs/outputs may improve Google products and be reviewed by humans.
OpenAI uses `store:false`, which does not guarantee zero provider retention.
Exclude people, private identities, health profiles, personal history and
confidential information. Package photos and raw OCR are never stored in our
database or private account sync. Eligible provider access restrictions apply.
[AI privacy and limits](architecture/AI_ROUTING.md) · [Gemini terms](https://ai.google.dev/gemini-api/terms).

Before hosted use, verify Vercel's applicable data-use terms/account opt-out and avoid logging request bodies or sensitive data. [Vercel terms](https://vercel.com/legal/terms). No billing upgrade is part of this plan.

## Access and untrusted input

Treat OCR, source excerpts and community data as untrusted data, including embedded instructions. Bound text/response sizes and validate fixed schemas. Machine extraction proposes qualified fields; it cannot overwrite deterministic outcomes or supply missing evidence. No generated explanation route is implemented.

Public writes accept verified Firebase anonymous, password or Google scanner
tokens. Private library sync requires password or Google authentication and derives
ownership from the verified subject; payload identity cannot choose an owner.
Backend-only collections require dedicated private IAM credentials and server
validation. The separate profile-media exception verifies the non-anonymous
owner UID and strict schema in Firestore rules. Review is never client-assigned. Transactional admission cannot
guarantee provider availability. Keep Spark/no linked billing and no paid fallback.
Local source/emulator and live Firebase checks are distinct from hosted API proof.


AI remains disabled in clean-clone defaults. The supplied operator keys enable
bounded optional photo extraction; one shared Firestore selection applies to all
tasks and users, with sticky manual/failure replacement. Synthetic evidence is
separate from real-package or device accuracy. Optional Google/password login is implemented without an admin/reviewer role or
dashboard. The app has one scanner/client role; public facts and useful analysis
remain available to guests through automatic anonymous write authentication. CORS restricts browser access and is not authentication. Neither a shared
APK/web secret nor a deployment-automation bypass token belongs in clients.
`BACKEND_BASE_URL` is public configuration.

Native requests are not protected by CORS. Global AI selection/activation requires the separate server-only machine credential. AI admission uses shared bounded Firestore counters rather than instance-only counters. On exhaustion/failure, keep unknowns or read locally.
