# Unlabel feature workflows

The [20-group tracker](FEATURE_TRACKER.md) tracks the five supplied concept screens
without treating each group as equally sized. The [connected release plan](CONNECTED_RELEASE_PLAN.md)
selects backend **0.6.0 Product Discovery** and frontend **0.1.0+2 Connected Label
Reader** as independently published releases. Backend v0.7.0 private sync is implemented with 931 tests/5 emulator skips and 18 live Firebase checks; push/hosted/publication are pending. Frontend v0.2.0 Welcome/Home/optional account/5-tab navigation and useful destinations are implemented with release verification pending. Frontend v0.3.0 completes remaining reference-style screens separately. [Current checklist](ACCOUNT_SYNC_SCREEN_PLAN.md).

## Implemented connected slice

| Workflow | Behavior and boundary |
| --- | --- |
| Barcode lookup | Enter a supported printed barcode; open sourced dated report; a miss offers manual label entry |
| Name/brand discovery | Indexed OFF snapshot candidates, explicit barcode selection and bounded paging; broad/empty/unavailable states differ; similarity does not confirm the package |
| Current-label entry | Independently transcribe identity/declarations/rows/claims; preserve unknowns and units/basis; confirm front/back/pairing before submitting |
| Useful report | Current versus historical evidence, nutrition, approximate 4 g/cube total-sugar view, scoped claim checks and missing/conflicting facts |
| Ingredient detail | Three reviewed English/Hindi technological-function entries and original matched text; unmatched does not mean dangerous or safe |
| Automatic catalogue enrichment | Confirmed structured facts save through anonymous scanner Auth; exact retries deduplicate; storage outcomes do not discard analysis |
| Private saved/history | Recently viewed snapshots, explicit bookmarks/removal and independent list clearing; bounded device/browser guest storage; optional password accounts use a separate private CAS snapshot, never automatic guest import |
| Appearance | Responsive Material 3 white/forest/mint light (default)/dark/system UI with saved local choice, visible recovery and icon attribution |

Twenty backend paths/twenty-one operations include the preserved source/normalization/claim/community/
report APIs, catalogue search and separate authenticated private account sync. Existing live OFF routes and read-only
snapshot reports keep their separate origins. The client currently uses the
report/search contracts, not a second regulatory evaluator.
[Discovery](../architecture/PRODUCT_DISCOVERY.md) ·
[Reports](../architecture/LABEL_REPORT.md) · [UI](UI_REQUIREMENTS.md).

## 1. Marketing claim checking

Current manual entry can submit identified front claims with enough confirmed
back-table facts and applicability context. Seven reviewed numerical fibre/sugar/
sodium claims run only for their supported context. Results keep supported,
contradicted or insufficient-evidence states, relevant sources and scope.

High/source protein, no added sugar and multigrain remain recognized but unreviewed.
Total sugar cannot establish added sugar. Historical catalogue facts cannot prove
a claim printed on the person's current packet. No full-compliance badge,
fraud verdict or universal health score is produced.

Future front/back OCR will extract provisional claims/rows for correction; it
must preserve existing source identities and confirmation boundaries.

## 2. Camera ingredient highlighting — future

Native camera/OCR and browser capture/OCR must first be measured on readable
Indian packages. They will preserve boxes, frame identity, orientation/crop and
provisional status. Only corrected confirmed fields can enter final checks.

Highlighting the word salt does not prove high sodium. Numeric assessment needs
a reliable value, unit, compatible basis and reviewed applicability. Blur, glare,
curved wrappers, multiple labels and stale frames must lead to correction or
unknowns. Live overlay is not required for the current useful manual report.

## 3. Personalized suitability — future

Dietary/allergy choices are private and remain local for guests. Optional signed-in display-name/saved/history sync is implemented; dietary/health preferences are outside its strict payload. A future mapper may select
traceable neutral reasons from backend-issued facts without duplicating FSSAI
thresholds; profile sync is separate from report analysis and only follows optional login. Saved suitability would retain its profile/
policy version and date; changed preferences must not silently refresh old findings.

Declared ingredients, contains, may contain and uncaptured text remain distinct.
Unknown allergen data never establishes absence or safety. Personalization is not
a diagnosis or dietary treatment plan.

## 4. Ingredient explanations

Current reports match only the reviewed glossary's three technological functions:
lecithin INS 322(i), citric acid INS 330 and xanthan gum INS 415. English/Hindi
functions retain their original label match and source references. They do not
establish health effects, allergy safety or Indian permission for a food category.

Broader aliases/content and a complete language-switching UI remain future work.
Hindi glossary text does not prove Devanagari OCR works. No custom model or Gemini
call is selected for these explanations.

## Supporting work still needed

| Work | Acceptance boundary |
| --- | --- |
| Camera/barcode scanner and front/back/gallery OCR | Platform permission/lifecycle, local processing, correction/pairing and measured Indian-label accuracy |
| Broader comparison presentation | v0.2.0 compatible-basis client comparison is implemented with validation pending; v0.3.0 completes reference-style presentation without overall-health ranking |
| Preferences and broader language UI | Local privacy, traceable reasons and preserved qualifications |
| Wider Home insight coverage | v0.2.0 educational destinations are implemented with validation pending; future content needs reviewed sources and no fake advice/recent scans |
| Broader source coverage | Rights-cleared data, exact product identity, original provenance and measured gaps; generic foods never impute branded nutrients |
| Offline website and native devices | Explicit cached-asset/first-load behavior and actual Android/iOS/browser checks |
| Signed iOS distribution | Separate signing/installability requirements; unsigned IPA is not an installable release |

No-card/free-tier constraints apply to every version. Firebase remains Spark with
no linked billing; photos/raw OCR/profiles/history stay private. Ordinary use
does not require AI, a training pipeline or a paid backend feature.

[System](../architecture/SYSTEM.md) · [Data flow](../architecture/DATA_FLOW.md) ·
[Release/versioning](RELEASE_VERSIONING.md)
