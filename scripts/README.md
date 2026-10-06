# Backend contracts and catalogue tools

Backend v0.2.3 includes the tools below. Run them from the repository root with the backend Python environment; acquisition/import are explicit local operations, never work performed by an API request.

| Tool | Responsibility |
| --- | --- |
| `setup.py` / `setup.ps1` | Restore env/dependencies, verified committed source to SQLite and pinned Flutter tooling. |
| `run_local.py` / `run-local.ps1` | Run localhost API/web services with process-only settings and owned-process cleanup. |
| `env.py` | Encrypt env to age ciphertext or restore using a key file/hidden terminal paste. |
| `lock_backend.py` | Record tested backend development dependency versions; run with backend `.venv` Python after deliberate dependency updates. |
| `export_backend_contracts.py` | Regenerate current OpenAPI/model schemas and owned synthetic examples, preserving historical OpenAPI and the product v1 contract. See [contract exports](../contracts/README.md). |
| `acquire_india_catalogue.py` | Stream the official global compressed OFF CSV through EOF into an India-tagged identity JSONL projection and acquisition metadata. It retains no global raw dump, nutrition aggregates or product images. |
| `acquire_india_jsonl.py` | Stream the full official JSONL gzip through validated EOF into a bounded India projection, with direct nutrition input sets, tag/date availability and selected-front image metadata. No global dump, photo bytes, aggregate nutrient values or arbitrary image URLs are retained. |
| `import_india_catalogue.py` | Validate local JSONL/gzip input and generate immutable identity plus optional bounded facts storage with matching keys/counts, dates, hashes and attribution. See [backend setup](../backend/README.md) for commands and optional catalogue configuration. |
| `../backend/build_catalogue.py` | Networkless deployment build: verify the tracked source bundle and generate/verify ignored `backend/app/catalogue/data/` SQLite/receipt. Run from `backend/` with its Python environment. |

The earlier CSV projection remains an identity input; its aggregate nutrient columns do not become direct label evidence. The current JSONL projection uses the same strict direct-table parser as live nutrition while retaining separate export provenance. Only packaging/manufacturer inputs qualify; missing, invalid and legacy-unsupported nutrition remain explicit. Canonical tags have availability states; present empty community tags do not prove allergy safety. Selected-front URLs use validated OFF metadata, canonical image-path normalization and image attribution; exact identity keys preserve leading zeros. No image proxy/download is added.

The completed JSONL acquisition has 24,695 exact India rows and 24,641 supported indexed records. Source **2026-10-06T06:53:46Z** is due **2027-07-06T06:53:46Z**. Complete source processing does not establish every product sold in India; coverage remains `unverified`. [Dated source/facts/build measurements](../docs/research/CATALOGUE_V0_2_3_COVERAGE.json) · [Current review](../docs/planning/BACKEND_V0_2_3_REVIEW.md).

Large network acquisition is authorized, but transfer, decoded-record, work-directory and output limits remain finite. Use a dedicated owned source/output directory, preserve the current valid catalogue during local import, and refresh manually every nine calendar months from source export. Keep reusable reviewed source/provenance/licenses in Git; regenerated SQLite stays ignored. Hosted refresh creates a new verified immutable deployment and supports previous-deployment rollback; it never writes packaged runtime files in place. Catalogue lookup requires a valid configured index, with a receipt also required on Vercel. No Firestore or dynamic user-cloud store has been selected. [Build/status/refresh workflow](../docs/architecture/CATALOGUE.md).

Existing same-source JSONL identity-only databases remain readable and are preserved by default setup. Use `scripts/setup.py --catalogue-only --replace-catalogue` to rebuild their facts table deliberately; intact facts stores and CSV identity stores retain normal reuse. This migration and actual local restore passed in the **402-test** v0.2.3 scope. [Hosted catalogue proof](../docs/research/BACKEND_V0_2_3_PRODUCTION.json).

Future tools will validate reviewed knowledge records/references and stage a reproducible read-only backend evidence bundle. A small versioned preinstalled Flutter glossary export is optional; no offline Dart rule bundle or mandatory Dart/Python evaluator-parity tool is required. The manual release workflow already contains its own artifact-validation steps.

Exports should share one knowledge-version identifier and never include private scans or provider credentials. Source fetching must respect reuse rights; do not make automatic regulator scraping or paid embeddings part of the scan path.

Keep source-tagged read-only Open Food Facts snapshots separate from reviewed FSSAI knowledge and private scans. New analysis requires the online backend or an existing laptop/LAN backend; limited offline access covers dated saved reports, local preferences/drafts and an optional preinstalled glossary. Backend templates remain the fallback when Gemini fails. No tool should relabel cached reports as fresh analysis.
