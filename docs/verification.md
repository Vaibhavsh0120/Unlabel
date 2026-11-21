# Verification

Verify the behavior changed and the boundaries it crosses. A source review or
successful build does not establish hosted integration, native installation or
physical-device behavior. Record the source SHA, environment, commands and any
remaining gates with the release or deployment evidence.

The legacy Vercel/Firebase application is still serving. The Coolify replacement
remains incomplete; successful individual service tests do not establish complete
cutover. See [deployment](deployment.md) and [the roadmap](roadmap.md).

## Repository and backend

From the repository root after [setup](development.md):

```powershell
python scripts/release/validate_workspace.py
python scripts/release/check_docs.py
backend/.venv/Scripts/python.exe -m unittest discover -s scripts/tests -p 'test_*.py'
backend/.venv/Scripts/python.exe -m ruff check --config backend/pyproject.toml backend/app backend/tests backend/build_catalogue.py scripts
```

From `backend`:

```powershell
.venv/Scripts/python.exe -m pip check
.venv/Scripts/python.exe build_catalogue.py
.venv/Scripts/python.exe -m pytest -q
```

On macOS/Linux use `.venv/bin/python`. The legacy catalogue build verifies source
bundles and generates ignored read-only indexes and knowledge receipts; it is not
the self-hosted database migration. Preserve canonical inputs under `data/catalogue`
and `data/knowledge`. For changed API contracts, run
`scripts/release/export_backend_contracts.py` with the backend interpreter from the
root, review generated schemas/examples and run contract tests. Keep historical
contract fixtures rather than regenerating them as current output.

The workspace validator checks source syntax, private-key patterns and canonical
metadata. The documentation checker verifies local targets and anchors in tracked
Markdown. Review staged paths and diffs separately, especially after moving source
and provenance files.

## Frontend

From `frontend` with the pinned Flutter toolchain:

```powershell
flutter pub get --enforce-lockfile
node --test test/*_web_test.cjs ../infrastructure/firebase/auth-bridge.test.cjs
flutter analyze
flutter test
flutter build web --release --no-pub
```

For UI changes, render phone, portrait/landscape tablet and desktop layouts in both
themes. Include shorter desktop windows, large text, keyboard visibility, empty
states and realistic item counts. Check readable type, complete identity text,
card space, symmetry, navigation reachability and image sizing. Preserve the
stationary desktop shell and Home/Scan/Compare/Saved order. Use measured layout
evidence where available; an accessibility DOM around a Flutter canvas does not
measure every painted card's padding.

Exercise reduced motion, focus/keyboard controls, screen-reader labels and
permission denial. Haptic feedback, camera focus/zoom, Safari viewport behavior
and native notification scheduling need real supported devices; emulators and
browser previews are complementary evidence.

## Self-hosted integration

CI now has a separate disposable-PostgreSQL job for the self-hosted profile,
community and worker suites, plus an identity-source image build. Its outcome
must be checked on the pushed commit. Local skips without PostgreSQL do not count
as passing integration tests. Browser-script tests cover popup origin/source
binding, PKCE, recovery-token handling and callback URL clearing; they do not
prove Google consent, SMTP delivery or native SDK behavior.

Use disposable test databases and synthetic identities. Never supply production
credentials to a generic test command. Tests requiring an explicit database
connection may skip without one; a skipped test is an unverified gate.

The guest-lifecycle suite uses `UNLABEL_TEST_POSTGRES_ADMIN_DSN` to create its own
temporary database and role. Run
`python -m pytest tests/integration/test_guest_cleanup.py -q` from `backend` with
the self-hosted test dependencies installed and an isolated test connection set
through the environment. It covers expiry, conversion protection, role grants and
concurrent session activity. Do not paste the connection string into command logs.

Before cutover, demonstrate:

- Public Oracle `/openapi.json` matches the committed self-hosted 1.0 contract and deployed source SHA; `/v1/platform` reports `cutover_ready: true` only after all other acceptance gates pass.
- PostgreSQL/MongoDB source import parity, immutable hashes, exact identity and
  conflict handling without silently replacing source evidence.
- Owner isolation, recent-auth account deletion, provider collision protection,
  profile/sync behavior and device-local guest preservation.
- Email verification/reset delivery and link completion, Google sign-in on each
  platform, session refresh/revocation and inactive-guest cleanup.
- Real browser push and native reminder permission, delivery, deduplication and
  unsubscribe, including failure/expired-subscription behavior.
- Durable outbox concurrency, fenced leases, retries, bounded maintenance,
  process restart behavior and independent backup restoration.
- Private network/grants, intended public routes, resource limits, image review
  and isolation from unrelated Coolify projects.

## Publishing evidence

Follow [the release guide](releases.md). GitHub Actions runs on repository events
or manual dispatch; reminders and maintenance do not use Actions cron schedules.
After push, check the actual CI result and deployed source SHA. Verify the public
frontend and API together, then native assets and the stable iOS feed separately.
Archive diagnostics as CI artifacts or release evidence without private scans,
tokens or credential values.

Only retire the legacy backend/Firebase resources after the replacement and client
release pass their required checks. Report remaining physical-device or provider
gates explicitly rather than treating published artifacts as acceptance.
