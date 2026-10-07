# Backend v0.5.0: Useful Label Report

Released on **7 October 2026**. v0.4.0 Community Product Catalogue is
already separately published; this next version gives a future client one useful
report response to render. Both versions were independently reviewed, pushed,
hosted-verified and published.

## Goal and behavior

`POST /v1/reports/check` accepts confirmed corrected package facts, including
barcode-less ingredients or nutrient rows. It returns original/normalized rows,
selected-basis sugar illustration, reviewed numeric claim checks, ingredient
functions, declaration evidence and explicit missing inputs. Anonymous storage
runs automatically, with its own status when saving is unavailable or blocked.

`GET /v1/products/{barcode}/report` returns dated catalogue evidence with sources,
alternatives and conflicts; it never establishes current-package confirmation.
`GET /v1/ingredients/glossary` exposes three sourced English/Hindi functions with
a version and content hash. Historical routes and exports remain compatible.

Only scanner client accounts belong to the app. No admin/reviewer account or
dashboard is introduced. Photos/OCR, health scores, comparison, Gemini and custom
training remain future work; the glossary is deliberately partial. This release
does not claim complete Indian retail coverage or medical/allergy safety.

## Version and validation

Backend is **0.5.0**; Flutter stays **0.0.0+1**. API major and schema remain **1**,
with additive `label-report-v1` models/routes and independent glossary version.
Actual local settings and tracked age ciphertext were refreshed without exporting
plaintext credentials. No new cloud billing/card requirement was introduced.

Review and local checks passed: **807 tests**, zero Pyright errors/warnings,
Ruff/format, contracts, scripts/Markdown links, actual setup and source build.
Five unchanged storage emulator cases are excluded from this suite and retain
their separate v0.4.0 proof. Source **0c067027c934226fc2cd6880a319128ea26d9ebf**
was pushed independently. Both exact-commit deployments reached READY; twenty
hosted API checks and two website HTTP checks passed. Synthetic records and test
users were cleaned up. The [source-only GitHub release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.5.0)
targets that source. No APK/IPA or historical release tag was rebuilt or moved.

[Review and evidence](BACKEND_V0_5_0_REVIEW.md) ·
[Architecture](../architecture/LABEL_REPORT.md) ·
[Feature tracker](FEATURE_TRACKER.md).
