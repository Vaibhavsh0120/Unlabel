# Backend contracts, catalogue and knowledge tools

Current component versions come from [backend pyproject](../backend/pyproject.toml)
and [frontend pubspec](../frontend/pubspec.yaml); earlier independently published
source releases remain preserved. Run them from the repository root with the backend Python environment; acquisition/import are explicit local operations, never work performed by an API request.

| Tool | Responsibility |
| --- | --- |
| `version_metadata.py` | Read frontend pubspec/backend pyproject and pinned Flutter metadata; JSON or GitHub outputs. No duplicated release defaults. |
| `validate_workspace.py` | Validate source syntax, Markdown links, private-key boundaries, README version badges against canonical manifests and the current backend OpenAPI export; includes added/deleted source files. |
| `prepare_android_ci.py` | CI-only SDK/NDK preparation and bounded Gradle settings from the pinned Flutter SDK. |
| `package_ios.py` | Validate the built device app and package a symlink-preserving unsigned arm64 IPA. |
| `mobile_release.py` | Guard immutable native tags, verify/upload artifacts and publish a draft only after complete checks; refresh the dedicated iOS feed. |
| `ios_source.py` | Generate/merge AltStore-compatible source from actual verified IPA metadata/bytes, preserving version history. |
| `setup.py` / `setup.ps1` | Restore env/dependencies, verified committed source to SQLite and pinned Flutter tooling. |
| `_progress.py` | Internal dependency-free setup progress: measured catalogue byte bars, indeterminate work/elapsed time and plain stage/failure logs. Not a separate command. |
| `run_local.py` / `run-local.ps1` | Run localhost API/web services with process-only settings and owned-process cleanup. |
| `generate_app_icons.py` | Regenerate authored light/dark iOS/Android/web icons with optional Pillow; `--check` validates tracked icon sizes/hashes/references using the standard library. See [brand assets](../frontend/assets/brand/README.md). |
| `env.py` | Encrypt env to age ciphertext or restore using a key file/hidden terminal paste. |
| `lock_backend.py` | Record tested backend development dependency versions; run with backend `.venv` Python after deliberate dependency updates. |
| `community_catalogue.py` | Guarded private pending/inspect/approve/reject/cleanup operations for automatic community observations; explicit project and exact review hash. |
| `export_backend_contracts.py` | Regenerate current OpenAPI/model schemas and owned synthetic examples, preserving historical OpenAPI and the product v1 contract. See [contract exports](../contracts/README.md). |
| `acquire_india_catalogue.py` | Stream the official global compressed OFF CSV through EOF into an India-tagged identity JSONL projection and acquisition metadata. It retains no global raw dump, nutrition aggregates or product images. |
| `acquire_india_jsonl.py` | Stream the full official JSONL gzip through validated EOF into a bounded India projection, with direct nutrition input sets, tag/date availability and selected-front image metadata. No global dump, photo bytes, aggregate nutrient values or arbitrary image URLs are retained. |
| `import_india_catalogue.py` | Validate local JSONL/gzip input and generate immutable identity plus optional bounded facts storage with matching keys/counts, dates, hashes and attribution. See [backend setup](../backend/README.md) for commands and optional catalogue configuration. |
| `../backend/build_catalogue.py` | Networkless deployment build: verify the tracked public/research catalogues and approved claim JSON, then generate/verify ignored `backend/app/catalogue/data/` SQLite/receipt and `backend/app/claims/data/` JSON/receipt. Successful stdout is one object with `catalogue`, `claims_knowledge` and `research_catalogue` receipts. Run from `backend/` with its Python environment. |

The earlier CSV projection remains an identity input; its aggregate nutrient columns do not become direct label evidence. The current JSONL projection uses the same strict direct-table parser as live nutrition while retaining separate export provenance. Only packaging/manufacturer inputs qualify; missing, invalid and legacy-unsupported nutrition remain explicit. Canonical tags have availability states; present empty community tags do not prove allergy safety. Selected-front URLs use validated OFF metadata, canonical image-path normalization and image attribution; exact identity keys preserve leading zeros. No image proxy/download is added.

Setup progress writes to stderr. On an interactive terminal, compressed and decoded catalogue verification shows real bytes against the expected total using B/KiB/MiB units, with `Verified` printed only after length/checksum validation succeeds. Existing-index validation, index construction and virtual-environment creation show an indeterminate bar and elapsed seconds because their total work is unknown. Pip installation/checks and pinned Flutter check/download/dependency restoration use named `Starting`/`Done`/`Stopped` stages while preserving the tools' own output. Redirected/noninteractive logs use plain lines without carriage-return redraws or guessed percentages. Failures show `Stopped`, never verified completion. No extra flag, dependency or progress-related download is required; scope, pinned versions, preserve/replace behavior and hidden-key input are unchanged.

The completed JSONL acquisition has 24,695 exact India rows and 24,641 supported indexed records. Source **2026-10-06T06:53:46Z** is due **2027-07-06T06:53:46Z**. Complete source processing does not establish every product sold in India; coverage remains `unverified`. [Dated source/facts/build measurements](../docs/research/CATALOGUE_V0_2_3_COVERAGE.json) · [Historical rich-facts review](../docs/planning/BACKEND_V0_2_3_REVIEW.md).

Large network acquisition is authorized, but transfer, decoded-record, work-directory and output limits remain finite. Use a dedicated owned source/output directory, preserve the current valid catalogue during local import, and refresh manually every nine calendar months from source export. Keep reusable reviewed source/provenance/licenses in Git; regenerated SQLite stays ignored. Hosted refresh creates a new verified immutable deployment and supports previous-deployment rollback; it never writes packaged runtime files in place. Catalogue lookup requires a valid configured index, with a receipt also required on Vercel. The separate configured Firestore `unlabel` database stores structured observations; immutable OFF storage is unchanged. [Build/status/refresh workflow](../docs/architecture/CATALOGUE.md).

Existing same-source JSONL identity-only databases remain readable and are preserved by default setup. Use `scripts/setup.py --catalogue-only --replace-catalogue` to rebuild their facts table deliberately; same-source facts stores without discovery are upgraded automatically; current indexed facts stores and CSV identity stores retain normal reuse. This migration and actual local restore passed in the **402-test** v0.2.3 scope. [Hosted catalogue proof](../docs/research/BACKEND_V0_2_3_PRODUCTION.json).

The current build validates exactly the two canonical reviewed claim JSON files, including rule/source references, bounds, dates and version, then packages hashes/lengths with a strict receipt. `--knowledge-directory` defaults to root `knowledge/`; `--knowledge-output-directory` defaults to `backend/app/claims/data/`. Catalogue `--source-directory`/`--output-directory` options retain their roles. Hosted activation requires receipt verification including explicit overrides; invalid packages never silently fall back. A small versioned preinstalled Flutter glossary export is optional; no offline Dart rule bundle or mandatory Dart/Python evaluator-parity tool is required. The manual release workflow already contains its own artifact-validation steps.

Exports should share one knowledge-version identifier and never include private scans or provider credentials. Source fetching must respect reuse rights; do not make automatic regulator scraping or paid embeddings part of the scan path.

Keep source-tagged read-only Open Food Facts snapshots separate from reviewed FSSAI knowledge and private scans. New analysis requires the online backend or an existing laptop/LAN backend; limited offline access covers dated saved reports, local preferences/drafts and an optional preinstalled glossary. Backend templates remain the fallback when Gemini fails. No tool should relabel cached reports as fresh analysis.

## Current validation and exports

From root, run `python scripts/validate_workspace.py` and
`python scripts/version_metadata.py --component frontend` (or `backend`).
The source validator reports only filenames/rule failures when sensitive material
is detected. `python -m unittest discover -s scripts/tests -p 'test_*.py'` checks
release/publication guards. Use `--target-version py312` for root Ruff checks so
standard-library imports are classified with the supported Python minimum.

Source generation accepts `--ipa PATH --download-url HTTPS_URL --date ISO_DATE
--icon-url HTTPS_URL --output PATH`, with optional `--existing PATH`, through
`python scripts/ios_source.py`. Normal publication runs this automatically after
a verified mobile release; a draft does not change the hosted feed.

The [current provider compatibility review](../docs/planning/BACKEND_V0_12_1_REVIEW.md)
keeps final source/hosted gates pending; the
[preceding v0.12.0 review](../docs/planning/BACKEND_V0_12_0_REVIEW.md) remains dated proof.

From root, run `backend/.venv/Scripts/python.exe -m pytest backend/tests -q`, then `backend/.venv/Scripts/python.exe scripts/export_backend_contracts.py` and review its 27-path/28-operation current-version OpenAPI and validated synthetic examples. Historical exports remain intact. From `backend/`, run `.venv/Scripts/python.exe build_catalogue.py` to exercise the network-free three-receipt build. Both output directories are generated/ignored, while canonical JSON stays in Git. v0.6.0 passed 863 backend tests with five emulator-only skips, static/source-build/setup/Markdown review and 23 hosted checks before separate publication. v0.5.0 retains its earlier twenty-check evidence. Completed v0.4.0 test/static/emulator/live/hosted evidence remains in its [release review](../docs/planning/BACKEND_V0_4_0_REVIEW.md). Review all scripts and Markdown, update affected tests/contracts and remove demonstrably dead code before each push. No script performs an automatic source refresh, native rebuild, paid provisioning or live regulator verification.

Optional static type checking is reproducible from root with `npm exec --yes --package=pyright@1.1.414 -- pyright --project pyrightconfig.json --pythonpath backend/.venv/Scripts/python.exe` (Unix: `backend/.venv/bin/python`). The checked-in root configuration covers maintained backend and script Python in basic mode. This development check needs Node/npm but introduces no npm project dependency or runtime service; backend restore/run still uses the documented Python tools.

## Community operator commands

Use backend-only configured credentials; never put secrets on the command line.
The explicit project must match settings. Commands from repository root:

~~~powershell
backend/.venv/Scripts/python.exe scripts/community_catalogue.py --project unlabel-india-catalogue pending --limit 20
backend/.venv/Scripts/python.exe scripts/community_catalogue.py --project unlabel-india-catalogue inspect REVISION_SHA256
backend/.venv/Scripts/python.exe scripts/community_catalogue.py --project unlabel-india-catalogue approve REVISION_SHA256 --expected-hash CONTENT_SHA256
backend/.venv/Scripts/python.exe scripts/community_catalogue.py --project unlabel-india-catalogue reject REVISION_SHA256 --expected-hash CONTENT_SHA256
backend/.venv/Scripts/python.exe scripts/community_catalogue.py --project unlabel-india-catalogue cleanup --limit 20
~~~

Replace placeholders with exact lowercase 64-character hashes from inspection.
Approval may add repeated `--supersedes REVISION_SHA256` for explicit same-barcode
replacement. Inspect carefully before review; stale hashes conflict. Cleanup
removes bounded expired private staging without paid TTL. Public lookup includes
qualified submitter-confirmed candidates as well as approved assertions; pending
conflicts and private receipt/ownership data stay nonpublic. These commands never
provision Firebase or enable billing. [Community guide](../docs/architecture/COMMUNITY_CATALOGUE.md).
