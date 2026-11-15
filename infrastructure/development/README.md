# Next-major data foundation

Development only. This stack is separate from production 0.12.0+17/0.16.0 and is
not referenced by either Vercel deployment or the native release workflow.

```powershell
python infrastructure/development/prepare.py
docker compose -f infrastructure/development/compose.yaml config --quiet
docker compose -f infrastructure/development/compose.yaml up -d
```

The secret generator never overwrites existing secrets or prints their values.
`.secrets/` is ignored and must remain local. Files use mode 0600 where supported;
Windows permissions still depend on the enclosing directory's ACL. These are
development bootstrap credentials, not production application roles.

PostgreSQL app/auth stores are separate. MongoDB is authenticated, and Redis cache
and job instances have distinct password ACLs/key namespaces. Cache eviction and
job persistence have different policies. Database ports are not published. The
`unlabel-next-dev` project/volume namespace and internal network isolate this
stack from existing resources. The configured memory ceilings total about 2.6
GiB before Docker/Coolify/host overhead; prove actual host capacity first.

Image manifests were checked against Docker Hub on 14 November 2026 and pinned
by digest. They support Linux amd64/arm64. Keep an upgrade/patch review rather
than following floating tags. GoTrue v2.197.0 is the auth candidate; its API,
Google flows and email transport spike comes after the data-store baseline.

The initial SQL schema is
`backend/migrations/next_major/0001_foundation.sql`. It is not auto-applied: the
versioned migrator, least-privilege runtime roles and PostgreSQL integration
tests are the next work items. MongoDB is currently a standalone development
document store. Replica-set authentication/bootstrap, transaction tests and
production topology must be implemented before moving transactional observation
admission. Do not treat this development stack as production-ready.

Local Docker's daemon was unavailable at the initial checkpoint. Compose model
validation can run without it; engine startup, SQL execution and restart/restore
tests remain pending. No production store, auth service, domain, or Firebase
resource was changed by preparing these files.

See [architecture decision](../../docs/architecture/SELF_HOSTED_PLATFORM.md)
and [major rebuild plan](../../docs/roadmap.md).
