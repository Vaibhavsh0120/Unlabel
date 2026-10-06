# Backend contracts and catalogue tools

Backend v0.2.1 includes the tools below. Run them from the repository root with the backend Python environment; acquisition/import are explicit local operations, never work performed by an API request.

| Tool | Responsibility |
| --- | --- |
| `setup.py` / `setup.ps1` | Restore env/dependencies, verified committed source to SQLite and pinned Flutter tooling. |
| `run_local.py` / `run-local.ps1` | Run localhost API/web services with process-only settings and owned-process cleanup. |
| `env.py` | Encrypt env to age ciphertext or restore using a key file/hidden terminal paste. |
| `lock_backend.py` | Record tested backend development dependency versions; run with backend `.venv` Python after deliberate dependency updates. |
| `export_backend_contracts.py` | Regenerate current OpenAPI/model schemas and owned synthetic examples, preserving historical OpenAPI and the product v1 contract. See [contract exports](../contracts/README.md). |
| `acquire_india_catalogue.py` | Stream the official global compressed OFF CSV through EOF into an India-tagged identity JSONL projection and acquisition metadata. It retains no global raw dump, nutrition aggregates or product images. |
| `import_india_catalogue.py` | Validate local OFF JSONL or the CSV-derived projection and build an immutable SQLite identity catalogue with counts, dates, hashes and attribution. See [backend setup](../backend/README.md) for commands and optional catalogue configuration. |

The CSV projection is an identity catalogue source, not a v3.6 nutrition-table export. Live OFF nutrition lookup remains separate. A successful import measures records present in its input; it does not prove every product sold in India is covered. Acquisition progress and final coverage/storage measurements belong in the [feasibility record](../docs/research/INDIA_EXPORT_FEASIBILITY.md).

Large network acquisition is authorized, but transfer, decoded-record, work-directory and output limits remain finite. Use a dedicated source/output directory outside Git, preserve the current valid catalogue during replacement, and refresh manually every nine months after validation. Catalogue lookup stays disabled unless a valid local catalogue directory is configured. A generated local SQLite catalogue is read-only product data; no Firestore or dynamic user-cloud store has been selected.

Future tools will validate reviewed knowledge records/references and stage a reproducible read-only backend evidence bundle. A small versioned preinstalled Flutter glossary export is optional; no offline Dart rule bundle or mandatory Dart/Python evaluator-parity tool is required. The manual release workflow already contains its own artifact-validation steps.

Exports should share one knowledge-version identifier and never include private scans or provider credentials. Source fetching must respect reuse rights; do not make automatic regulator scraping or paid embeddings part of the scan path.

Keep source-tagged read-only Open Food Facts snapshots separate from reviewed FSSAI knowledge and private scans. New analysis requires the online backend or an existing laptop/LAN backend; limited offline access covers dated saved reports, local preferences/drafts and an optional preinstalled glossary. Backend templates remain the fallback when Gemini fails. No tool should relabel cached reports as fresh analysis.
