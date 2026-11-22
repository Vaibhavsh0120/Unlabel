# Local development

Use this guide for the supported setup and runner. Read [the roadmap](roadmap.md)
for unfinished work and [verification](verification.md) before publishing.

## Prerequisites and recovery

Install Git, a Python version satisfying [backend metadata](../backend/pyproject.toml),
and [age](https://github.com/FiloSottile/age). The Flutter version is pinned in
[workspace configuration](../scripts/config/workspace.json); setup reuses a matching
SDK or installs an isolated copy under the ignored `.local-tools` directory.
Android and iOS builds require their own platform toolchains.

From PowerShell in the repository root:

```powershell
.\dev.ps1
```

The menu opens setup, run modes, secret recovery and common checks. Use
`.\dev.ps1 -List` to see the actions without starting one. Each tool also runs
directly for use from an editor or other shell.

```powershell
.\secrets\secrets.ps1 decrypt
.\secrets\secrets.ps1 verify
python scripts/setup.py
python scripts/run_local.py
```

Decrypt prompts for the age private key with input hidden. Keep that key outside
the repository and keep an independent copy. A key-file path may be supplied with
`-Identity`; never paste a key into chat, a command argument or tracked files.
Restoration preserves identical files and refuses conflicting existing values
unless replacement is explicitly requested. See [secret recovery](../secrets/README.md).

The PowerShell wrappers `scripts/setup.ps1` and `scripts/run-local.ps1` expose the
same setup and runner. On macOS/Linux use `python3` and the platform's virtual
environment executable paths. First-time dependency and SDK installation needs
internet. Restored production credentials do not authorize experiments against
production data; use isolated development services for tests.

## Setup and run modes

```powershell
python scripts/setup.py --scope backend
python scripts/setup.py --scope frontend
python scripts/run_local.py --mode local
python scripts/run_local.py --mode production
python scripts/run_local.py --mode lan
```

Setup preserves the existing environment, installs locked dependencies and checks
committed source hashes. Safe example settings are available without private
credentials using `--non-interactive`. Optional account and extraction services
remain unavailable until configured; setup does not provision cloud resources.

The current runner starts the legacy backend entry point. Its generated read-only
SQLite indexes remain part of legacy local development; they are not the database
design selected for the new Coolify backend. The production runner mode starts a
local frontend against the currently configured hosted API and starts no local
backend. Read [deployment](deployment.md) before testing the migration endpoint.
The launcher prints build progress while Flutter compiles, then prints the
clickable local preview address. Keep that terminal running while using the app.

Default ports come from workspace configuration. The runner prints the actual
frontend and API addresses, rejects occupied ports and stops its own process trees
on Ctrl+C or service failure. It does not kill unrelated processes or rewrite the
environment. Use `--backend-port`, `--web-port`, `--scope` and `--backend-url` for
explicit overrides. LAN mode uses a local HTTPS proxy; certificate and firewall
setup are documented in [the tools guide](../scripts/tools/README.md).

Use `--replace-catalogue` only for a deliberate replacement with the committed
source. Preserve valid existing indexes and acquired sources when investigating
an importer failure. Source bundles, manifests, licenses and receipts under
`data/catalogue` and `data/knowledge` are authoritative; generated databases and
build outputs are ignored.

## Where changes belong

| Area | Location |
| --- | --- |
| Flutter application and tests | `frontend/lib`, `frontend/test` |
| Backend application and tests | `backend/app`, `backend/tests` |
| Source bundles and reviewed knowledge | `data/catalogue`, `data/knowledge` |
| Public schemas and examples | `contracts` |
| Setup, runner and release tools | `scripts` |
| Coolify/Docker configuration | `infrastructure` |
| Retained design sources | `frontend/design_sources` |
| Legacy Firebase configuration | `infrastructure/firebase` |

Guest scans, saved items and preferences remain device-local. Signed-in libraries
use separate owner namespaces and explicit conflict choices. Test with synthetic
fixtures; private scans, identity files, plaintext environment files and generated
builds do not belong in Git.

After changing secrets, select encryption and verification from `./dev.ps1` or
run `.\secrets\secrets.ps1 encrypt` followed by `.\secrets\secrets.ps1 verify`.
Encryption invokes the configured PowerShell `agel` function and refreshes the
full-project ciphertext plus the legacy backend environment backup. Commit only
the encrypted bundle, public recipient and inventory metadata. A missing formerly
backed-up file causes refresh to fail rather than silently dropping that secret.

Changes to dependencies require reviewing the relevant lockfile and rerunning
the affected checks. Backend dependency-lock tooling is
`scripts/dev/lock_backend.py`; Flutter restoration uses `--enforce-lockfile`.
