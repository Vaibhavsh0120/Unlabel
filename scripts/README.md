# Workspace tools

Run `./dev.ps1` from the repository root for setup, run modes, secret recovery
and verification. Individual commands remain available for CI and automation.
See [local development](../docs/development.md) and [verification](../docs/verification.md).

| Area | Tools and purpose |
| --- | --- |
| Setup and run | `setup.py` / `setup.ps1` install locked dependencies and verify the local catalogue. `run_local.py` / `run-local.ps1` start the local, hosted-API or LAN setup. `dev/_workspace.py`, `_progress.py`, `_preview_server.py` and `_local_network.py` support these commands. |
| Secret recovery | `project_secrets.py` backs up and restores the full project through `secrets/secrets.ps1` or the developer menu. `env.py` retains legacy single-environment recovery and is used by setup and operator tools. See [secret recovery](../secrets/README.md). |
| Repository checks | `release/validate_workspace.py` checks source files, version badges and the current API export. `release/check_docs.py` checks tracked Markdown links and anchors. `release/version_metadata.py` reads canonical component and Flutter metadata. |
| Asset checks | `release/vendor_web_ocr.py`, `release/generate_app_icons.py` and `release/optimize_ui_assets.py` verify or regenerate maintained frontend assets. |
| Contract exports | `release/export_backend_contracts.py` updates current OpenAPI, model schemas and owned synthetic examples. Preserve historical exports. See [contract exports](../contracts/README.md). |
| Native publication | `release/frontend_release_gate.py`, `prepare_android_ci.py`, `package_ios.py`, `mobile_release.py`, `ios_source.py` and `organize_releases.py` support artifact preparation and verified publication. See [release operations](../docs/releases.md). |
| Catalogue acquisition | `data/acquire_india_jsonl.py` projects the official JSONL gzip. `data/acquire_india_catalogue.py` retains the historical CSV acquisition path for identity-only builds. `data/acquire_popular_products.py` collects bounded research inputs. |
| Catalogue build and backup | `data/import_india_catalogue.py`, `build_popular_dataset.py`, `build_research_catalogue.py` and `backup_catalogue.py` build or preserve reviewed catalogue inputs and derived stores. `backend/build_catalogue.py` prepares the legacy read-only deployment artifacts. See [catalogue workflow](../docs/architecture/CATALOGUE.md). |
| Operator configuration | `data/community_catalogue.py` reviews legacy community records. `ai/configure_ai.py` and `ai/ai_provider.py` manage optional extraction credentials and provider configuration. `notifications/configure_web_push.py` generates the VAPID configuration for web push. |
| Dependency maintenance | `dev/lock_backend.py` records tested backend development dependencies after an intentional change. The pinned toolchains, ports and local paths come from [workspace configuration](config/workspace.json). |
| Tests and local tools | `tests/` contains script checks. [Local HTTPS tools](tools/README.md) cover Caddy, certificate trust and LAN access. |

Run acquisition explicitly with bounded input/output and an owned working
folder under `.local/`. Preserve the committed bundles, licenses, manifests and
verified active index. Current source knowledge lives in `data/knowledge/`.
Legacy setup and deployment artifacts are derived from committed inputs. The
self-hosted catalogue uses PostgreSQL projections and immutable MongoDB evidence.

Use the backend virtual environment for tools with application imports. Run the
script tests from the root with `python -m unittest discover -s scripts/tests`.
The [verification guide](../docs/verification.md) defines the backend, frontend
and deployment checks.

## Community operator commands

Use backend-only configured credentials; never put secrets on the command line.
The explicit project must match settings. Commands from repository root:

~~~powershell
backend/.venv/Scripts/python.exe scripts/data/community_catalogue.py --project unlabel-india-catalogue pending --limit 20
backend/.venv/Scripts/python.exe scripts/data/community_catalogue.py --project unlabel-india-catalogue inspect REVISION_SHA256
backend/.venv/Scripts/python.exe scripts/data/community_catalogue.py --project unlabel-india-catalogue approve REVISION_SHA256 --expected-hash CONTENT_SHA256
backend/.venv/Scripts/python.exe scripts/data/community_catalogue.py --project unlabel-india-catalogue reject REVISION_SHA256 --expected-hash CONTENT_SHA256
backend/.venv/Scripts/python.exe scripts/data/community_catalogue.py --project unlabel-india-catalogue cleanup --limit 20
~~~

Replace placeholders with exact lowercase 64-character hashes from inspection.
Approval may add repeated `--supersedes REVISION_SHA256` for explicit same-barcode
replacement. Inspect carefully before review; stale hashes conflict. Cleanup
removes bounded expired private staging without paid TTL. Public lookup includes
qualified submitter-confirmed candidates as well as approved assertions; pending
conflicts and private receipt/ownership data stay nonpublic. These commands never
provision Firebase or enable billing. [Community guide](../docs/architecture/COMMUNITY_CATALOGUE.md).
