# Unlabel documentation

Component versions come from the [frontend manifest](../frontend/pubspec.yaml)
and [backend manifest](../backend/pyproject.toml), not duplicated release prose.

| Task | Guide |
| --- | --- |
| Clone, recover secrets and run | [Development](development.md) |
| Deploy or operate services | [Deployment](deployment.md) |
| Build and publish apps | [Releases](releases.md) |
| Check changes and acceptance | [Verification](verification.md) |
| Continue unfinished work | [Roadmap](roadmap.md) |
| Find source ownership | [Repository structure](architecture/FOLDER_STRUCTURE.md) |
| Recover credentials | [Encrypted secrets](../secrets/README.md) |

## Architecture and contracts

| Topic | Contract |
| --- | --- |
| System and hosting | [System](architecture/SYSTEM.md), [self-hosted platform](architecture/SELF_HOSTED_PLATFORM.md) |
| HTTP and shared models | [API](architecture/API.md), [schemas/examples](../contracts/README.md) |
| Product evidence | [Data flow](architecture/DATA_FLOW.md), [catalogue](architecture/CATALOGUE.md), [discovery](architecture/PRODUCT_DISCOVERY.md) |
| Sources | [Open Food Facts](architecture/OPEN_FOOD_FACTS.md), [optional sources](architecture/OPTIONAL_SOURCES.md), [live facts](architecture/LIVE_PRODUCT_FACTS.md) |
| Reports | [Label reports](architecture/LABEL_REPORT.md), [Product Info](architecture/PRODUCT_INFO.md), [comparison](architecture/SOURCED_COMPARISON.md) |
| Private data | [Accounts](architecture/ACCOUNT_PROFILE.md), [sync](architecture/PRIVATE_ACCOUNT_SYNC.md), [guest retention](architecture/GUEST_SESSION_LIFECYCLE.md) |
| Contributions | [Community](architecture/COMMUNITY_CATALOGUE.md), [AI routing](architecture/AI_ROUTING.md) |
| Client experience | [Insights](architecture/INSIGHTS.md), [interface contract](../frontend/DESIGN.md) |
| Privacy and uncertainty | [Safety/privacy](SAFETY_PRIVACY.md) |

## Maintaining these guides

Update the relevant guide with the code change. Keep commands/configuration at
their owning component; link to manifests instead of copying versions, route
counts or old test totals. Keep one roadmap. Release notes belong in
[GitHub releases](https://github.com/Vaibhavsh0120/Unlabel/releases). Historical
evidence remains in Git history and the [source ledger](../contracts/versioning/releases.json).
Fixed source receipts and licenses stay beside their data. Do not add another
dated planning/review directory to the maintained documentation.

CI checks local links and heading anchors offline. This catches broken navigation,
not semantic drift: verify the implementation described by a changed guide.
