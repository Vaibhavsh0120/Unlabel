# Connected product releases

Accepted scope: 7 October 2026. The user authorized the next backend and frontend
versions after the separately released v0.5.0 report backend. Preserve those tags.

## Backend v0.6.0 — Product Discovery

Goal: find a dated packaged-product candidate by name/brand words without a barcode,
then select its exact barcode and use the existing sourced report.

- [x] Add optional indexed Unicode exact-token/final-prefix discovery to the existing
  read-only snapshot. Bound query size, candidate work, result count and cursor.
- [x] Keep Manifest/schema/API major 1 and every existing route/component compatible.
- [x] Return broad-query refinement, unavailable indexes and misses distinctly.
- [x] Bind pagination to the query, snapshot and options; reject stale cursors.
- [x] Upgrade generated indexes from the same acquired source through ordinary setup.
- [x] Export contracts; review tests, scripts, Markdown and secret boundaries.
- [x] Build, push, verify the exact hosted artifact and publish source-only v0.6.0.

No upstream search requests, generic-food inference, model training or Gemini.
The snapshot contains India-tagged OFF records, not measured Indian retail coverage.
Search does not cover community-only records in this version. Similarity is only
candidate discovery; selecting a record does not confirm the user's current packet.

## Frontend v0.1.0+2 — Connected Label Reader

Goal: a person can look up a product or enter their current label, read useful
sourced facts, and keep dated results locally.

- [x] Replace the starter with responsive white/forest/mint Flutter Material 3 UI.
- [x] Implement barcode entry, bounded name search and candidate selection.
- [x] Render current/historical reports with original basis, missing facts, sources,
  approximate sugar cubes, reviewed claims and partial ingredient functions.
- [x] Enter corrected identity, declared ingredients/allergens and nutrient rows.
  Keep blank unknown, original units and explicit denominator/preparation.
- [x] Confirm fields/pairing and save public package facts automatically using only
  anonymous scanner authentication; report analysis separately from storage outcome.
- [x] Implement bounded local saved reports/history and appearance preference, with
  deletion and explicit persistence failures; do not upload private history.
- [x] Test meaningful data/behavior boundaries and small/large/light/dark/2x layouts.
- [ ] Review rendered web flows, documentation, scripts and component-specific tags.
- [ ] Push after backend discovery is hosted; publish source-only frontend-v0.1.0.

Camera, gallery/OCR highlights, comparison, personal suitability and insight feed
remain follow-up work in the feature tracker. Do not add non-working buttons or
invent the concept images' 85/100 score, example product facts or health verdicts.
No APK/IPA rebuild is needed for this web/source release; native device behavior
will have a separate measured gate.

User steering: light is the first-use default; saved appearance persists locally.
Light/dark app icons are supplied for iOS, Android and web. Personal data stays
on-device; confirmed public package facts continue automatic catalogue storage.

## Next accepted work after this pair

Backend v0.7.0/frontend v0.2.0 adds optional scanner login/profile/private sync and
adds first-launch Welcome, Home and the Home/Scan/Compare/Saved/Profile bar. Frontend v0.3.0 completes remaining reference-style screen destinations in a separate reviewed/pushed release. The later light/dark brief
expands the earlier Home-only slice: implement and review one screen at a time,
with every visible action working. Guests keep personal data local; signed-in
personal records remain private and separate from automatic public package facts.
[Accepted next plan](ACCOUNT_SYNC_SCREEN_PLAN.md).

## Ownership and verification

Backend discovery owns catalogue search/index/store/import/API tests. Frontend data
owns bounded HTTP/models/local storage/anonymous auth and corrected entry. Frontend
UI owns themed navigation/lookup/report/history widgets. Root owns integration,
configuration, docs, contracts, script review, release and hosted/rendered evidence.
Preserve concurrent edits and each component's release boundary.

Regression focus: unknown versus zero; stale responses/cursors; malformed or broad
queries; current versus historical evidence; idempotent public storage; namespace-
bounded local removal; source receipt integrity; no secrets or private scan data.

The green reference direction is chosen by the user. It improves visual continuity
and comfortable mobile grouping; large text needs taller cards and less side-by-side
content. That trade-off affects small-screen users and is handled with reflow.
