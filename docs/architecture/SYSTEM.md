# System

Unlabel is a Flutter client with a Python FastAPI backend. It reads labels, shows
qualified product evidence, compares compatible nutrition tables and keeps
optional private libraries. Missing facts remain unknown; there is no invented
universal health, allergy-safety or legal-compliance verdict.

The client uses local barcode/OCR first, then bounded backend lookups. Cloud
photo extraction requires consent. Backend domains cover catalogue, research,
claims, reports, comparison, community, accounts, AI and notifications. Models
and routes live beside their implementation with shared
[contracts](../../contracts/README.md).

The published deployment still uses Vercel API hosting and Firebase identity/data.
A [self-hosted platform](SELF_HOSTED_PLATFORM.md) is being built on Oracle/Coolify
with PostgreSQL, MongoDB and Redis. The replacement does not use SQLite. Its
[acceptance gates](../roadmap.md) must pass before cutover.

The [catalogue](../../data/catalogue/README.md), independent research observations
and [reviewed knowledge](../../data/knowledge/README.md) retain licenses, hashes,
dates and qualifications. Images are separate attributed URL descriptors;
decorative artwork is never evidence. Compatible facts can complement one another
while conflicts remain visible. Generic food tables never fill unknown branded
package values.

Guest libraries stay local. Account sync is explicit, owner-scoped and revision
checked. Profile thumbnails are bounded; originals and EXIF are not retained.
Dietary/allergen reminders, appearance and Insight bookmarks stay device-local.
Public product observations and unverified machine proposals remain separate
from account records. See [privacy](../SAFETY_PRIVACY.md) and [data flow](DATA_FLOW.md).

[Repository ownership](FOLDER_STRUCTURE.md), [development](../development.md),
[deployment](../deployment.md) and [verification](../verification.md) describe
maintained tools and operational checks. Versions come from manifests; release
history belongs to Git tags, the source ledger and GitHub releases.
