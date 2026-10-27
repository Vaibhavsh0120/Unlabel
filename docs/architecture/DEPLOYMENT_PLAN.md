# Website and shared API deployment

Updated **15 October 2026** against canonical [frontend](../../frontend/pubspec.yaml)
and [backend](../../backend/pyproject.toml) versions. The API has **30 paths /
32 operations**. Barcode-first capture preserves camera framing, front-name
matches require pack-size selection, and ProductInfoPage is the shared result
destination. Automatic back-label observations remain machine-unverified and
source-preserving. Optional NutriGraph facts are session-only and disabled
pending a key. Local, hosted, native and device proof are recorded separately.
[Frontend review](../planning/FRONTEND_V0_10_0_REVIEW.md) ·
[Backend review](../planning/BACKEND_V0_14_0_REVIEW.md) ·
[Product Info](PRODUCT_INFO.md) · [Live facts](LIVE_PRODUCT_FACTS.md).

Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app);
API: [unlabel-api.vercel.app](https://unlabel-api.vercel.app/docs).
Keep the project at **₹0 additional platform cost, no card and no billing upgrade**.
A local laptop/LAN backend remains available for demonstrations.

## Project boundaries

| Target | Repository root / runtime | Responsibility |
| --- | --- | --- |
| Website Vercel project | `frontend/`; static `build/web/` | Flutter website and same-origin OCR assets; calls shared HTTPS API |
| Backend Vercel project | `backend/`; FastAPI/Python | OFF, bulk/research catalogue, claims/reports/glossary, community, account sync, comparison and optional extraction |
| Android/iOS apps | `frontend/`; Flutter platform builds | Native artifacts use the same shared HTTPS API |
| Firebase Unlabel | Standard `unlabel` database in Mumbai | Backend-only facts/libraries/AI records; separate owner-only profile thumbnails/gender, Firebase Auth and a static email-action bridge |

`frontend/web/` is the Flutter platform directory. The backend entrypoint is
`app/main.py`; the single API remains shared across native/web clients.
Vercel hosts the website/API while native packages are built separately.
[Monorepo roots](https://vercel.com/docs/monorepos) ·
[FastAPI support](https://vercel.com/docs/frameworks/backend/fastapi).

## Build and source packaging

`frontend/tool/vercel-build.sh` uses the pinned workspace Flutter SDK, resolves the
tracked lockfile and builds release web output with public backend/build metadata.
The configured static root serves `build/web`. SDKs and build outputs stay ignored.
A separate prebuilt deployment would require the complete Vercel Build Output API
layout, including `.vercel/output/config.json` and static assets; the Flutter
output alone is not that layout. [Web build](https://docs.flutter.dev/deployment/web) ·
[Build Output API](https://vercel.com/docs/build-output-api/primitives).

Both hosted projects are connected to `main`. A Git push may start their automatic
deployments; the manual native/component release workflow does not itself deploy
Vercel. A successful build/release is separate from exact-source hosted proof.
[Workflow guide](../../.github/workflows/README.md).

The backend build hook runs `python build_catalogue.py` after dependency install.
It makes no acquisition/provider request and decrypts no settings. Outside-root
build access supplies tracked `data/catalogue/` and canonical `knowledge/`.

| Generated package | Verification |
| --- | --- |
| `app/catalogue/data/` | Bulk SQLite/receipt from preserved source hashes, counts, manifest and database integrity |
| `app/claims/data/` | Exactly two approved claim-rule/source JSON files and strict hash/length receipt |
| `app/research_catalogue/data/` | Independent SQLite/receipt from immutable researched observations |

Current build stdout contains `catalogue`, `claims_knowledge` and
`research_catalogue` receipts. These ignored build outputs are not maintained
manually. Hosted startup verifies each artifact before enabling its capability;
invalid knowledge cannot fall back to unverified canonical files. A failed build
must not be promoted. An outside-root setting alone does not prove runtime
packaging. [Catalogue/build/rollback](CATALOGUE.md) ·
[Python bundling](https://vercel.com/docs/functions/runtimes/python).

Changes to canonical knowledge, tracked data, contracts or packaging helpers must
be included in relevant build/verification. Backend-only release work does not
rebuild APK/IPA. Historical implementation SHAs remain distinct from later
documentation/maintenance commits.

## Immutable runtime and separate mutable storage

Packaged SQLite and knowledge are read-only deployment assets. Instances,
temporary directories and in-memory counters cannot store durable personal data.
Bulk source refresh occurs manually every nine calendar months from export, after
validation; new source creates a new deployment with prior-source rollback.

Firestore stores mutable data under independent public/private/machine admission.
Anonymous/password/Google scanner tokens establish public-observation ownership;
password/Google private sync carries only bounded display name/saved/history
snapshots. Explicit cloud/device choices resolve differences. AI proposals stay
private and unverified, with separate storage outcomes. Package photos/raw OCR,
preferences, appearance, Welcome completion and Insight bookmarks stay outside
private library sync. Explicitly selected profile thumbnails and optional gender
use the separate owner-only `profile_media/{uid}` document. [Community](COMMUNITY_CATALOGUE.md) ·
[Private sync](PRIVATE_ACCOUNT_SYNC.md) · [AI routing](AI_ROUTING.md).

Firebase remains on its free Standard database with no linked billing or paid
fallback. Do not add paid Storage/Functions, TTL, backups or PITR. Client rules
deny every collection except a strict non-anonymous owner's profile-media
document; list access is denied. Least-privilege backend credentials remain
separate from scanner identities. [Auth/profile setup](ACCOUNT_PROFILE.md) records
public OAuth configuration, stable demo signing and Firebase's supported hosted
reset/Continue return. The current auth/provider and account-deletion source is
authorized for completion/push; exact-source hosted evidence remains separate.
Setup restores local source/runtime; it never provisions
a cloud account or payment plan.

## Optional extraction and public configuration

`BACKEND_BASE_URL` is public Dart build configuration. Exact website/local origins
are allowlisted; native calls do not rely on browser CORS. CORS cannot establish
identity or quotas. Provider keys and machine-control secrets stay server-only,
with encrypted local recovery; never place them in Dart/assets/workflow artifacts.

`AI_ENABLED` gates the optional Gemini/OpenAI gateway. `/v1/ai/extract` verifies
Firebase scanner tokens and explicit photo-transfer consent, then uses one globally
active configured credential with bounded attempts/cooldowns and Firestore quotas.
Selection/activation endpoints require the separate machine credential. There is
no reviewer/admin app role. Provider/data-use qualifications appear before
transfer. `store:false` is not a provider zero-retention promise.

Authentication, extraction and private staging response waits are separately
bounded. Unavailable/quota-limited cloud extraction falls back locally; deterministic
checks retain their source/confirmation rules. There is no generated explanation
route, generic chat endpoint, training dependency or key multiplication to bypass
quotas. [Current AI settings/admission/privacy](AI_ROUTING.md).

## Local OCR and offline boundaries

Android uses bundled ML Kit; iOS uses the existing capability-checked Vision
bridge; browser OCR uses pinned same-origin Tesseract/Wasm/language files. Photos
stay local unless optional transfer is consented. Geometry/raw OCR are excluded
from database/account sync. Native camera accuracy and measured scan performance
need physical-device evidence.

Saved dated reports, local reminders and bundled Insights remain useful after
loading. Fresh lookup/analysis needs the backend; a complete offline website needs
explicit app/content caching and airplane-mode restart checks. Browser camera
requires a secure context. Local storage/short-lived public read caches are not a
promise of an offline catalogue. No custom model hosting or paid compute is
required. [Data flow](DATA_FLOW.md).

## Verification and historical checkpoints

Validate current contracts, artifact receipts, source identity, HTTPS/CORS, failure
isolation and guest/password/Google namespace boundaries. Hosted proof must match its
implementation commit; local tests/builds, GitHub source/native releases, READY
status and native-device behavior are different evidence gates. Preserve original
catalogue/research records and dated receipts during cleanup.

The earlier frontend v0.3.0+4 checkpoint was independently published/hosted-verified;
backend v0.8.0 implementation
`1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` was pushed/hosted-verified with
25 checks, without source-publication proof from that receipt alone. Subsequent
v0.9.0/v0.4.0 checkpoints remain in their reviews. The v0.2.3 catalogue and v0.3.0
claim-build evidence remain dated historical proof. [Vercel setup](../planning/VERCEL_SETUP.md) ·
[Historical backend v0.1.0 review](../planning/BACKEND_V0_1_0_REVIEW.md) ·
[Historical backend v0.2.3 production](../research/BACKEND_V0_2_3_PRODUCTION.json).

Provider/account quotas and free hosting eligibility are finite. Platform terms
must be verified before changing deployment/provider scope; the local demo is the
fallback if a new requirement cannot fit the no-card constraint. No billing or
paid integration is introduced by this maintenance pass.
