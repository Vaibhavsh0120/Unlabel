# Repository structure

Keep documentation separate from executable tools, configuration and source data.
Shared contracts remain independent of the two application components.

| Location | Owns |
| --- | --- |
| `frontend/` | Flutter app, native/web projects, tests, interface contract and original design assets |
| `backend/` | FastAPI domains, self-hosted adapters, workers, migrations and tests |
| `contracts/` | Versioned schemas, OpenAPI exports, synthetic cross-client examples and source ledger |
| `data/catalogue/` | Licensed source bundles, manifests, acquisition inputs and attribution |
| `data/knowledge/` | Reviewed rules, source register and fixed provenance receipts |
| `infrastructure/` | Docker, development containers, Coolify references and legacy Firebase tooling |
| `scripts/` | Setup, run, source acquisition, validation, encryption and publication |
| `secrets/` | Ciphertext, public recipient/path inventory and recovery instructions; no private identity |
| `docs/` | Current development, deployment, release, verification, architecture and remaining work |
| `.github/` | Event-driven build/test/release workflows; no scheduled application jobs |
| `.local/` | Ignored generated catalogue and local source archives; not production database storage |
| `output/` | Ignored build reports, verification captures and temporary tool output |

`dev.ps1` opens the developer menu, including recovery through `secrets/secrets.ps1`. Component manifests
and workspace configuration own versions, dependencies, ports and toolchain pins.

Generated SDKs, virtual environments, builds and private captures stay ignored.
Setup creates missing directories; empty placeholder folders need not be tracked.
The legacy local catalogue is rebuilt from committed source under
`.local/backend/catalogue`. The replacement server reads PostgreSQL.

Frontend artwork masters and supplied references share
`frontend/design_sources/`; optimized runtime assets stay in `frontend/assets/`.
Licenses, provenance and hashes travel with source inputs. Design illustrations
cannot substitute for product evidence.

Firebase tooling remains in `infrastructure/firebase/` while the published app
depends on it. Removal follows the tested replacement in the
[roadmap](../roadmap.md), rather than breaking an active dependency.
