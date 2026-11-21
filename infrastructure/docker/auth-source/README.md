# Stable identity service security rebuild

`../auth.Dockerfile` rebuilds Supabase Auth **v2.197.0**, retaining its migrations
and applying the bounded [account policy patch](account-policy.patch). It uses Go **1.27.4** and explicitly reviewed dependency
updates rather than switching production to an upstream release candidate.
The exact commit, acquired archive checksum/size, MIT license and patched module
lock hashes are in [provenance.json](provenance.json). The upstream license text
is preserved in [LICENSE](LICENSE) and included in the image.

| Dependency | Upstream | Patched |
| --- | --- | --- |
| `golang.org/x/net` | 0.57.0 | 0.62.0 |
| `golang.org/x/crypto` | 0.55.0 | 0.59.0 |
| `google.golang.org/grpc` | 1.82.1 | 1.83.2 |
| `github.com/go-jose/go-jose/v4` | 4.1.4 | 4.1.6 |

`x/net` 0.62.0 requires at least `x/crypto` 0.58.0; the initially proposed minimum
0.56.0 cannot resolve with it. A binary vulnerability check then required the
newer crypto 0.59.0 and gRPC 1.83.2 fixes. Go module resolution also updates `x/mod`, `x/sync`,
`x/sys` and `x/text`; their exact versions and sums are retained. Docker builds
verify downloaded module checksums and use `-mod=readonly` for tests/builds.
Application source is fetched from an immutable commit and SHA-256 checked before
extraction; no upstream source archive or generated executable is committed.

The `.2` image refuses automatic external-provider linking based on a matching
email. Linking must instead prove the current owner and use GoTrue's explicit
link operation; a credential owned by another user remains a collision. Removing
an email identity clears its password verifier in the same transaction, while
the upstream rule still requires another identity to remain. The patch applies
only to the pinned upstream source and is checked before compilation. The
historical `local_build` receipt in provenance describes `.1`; it is not proof
that `.2` has built, started or passed account acceptance.

The final `scratch` image contains the static auth and healthcheck executables,
CA roots from the pinned builder, Go timezone data, migrations and licenses.
It runs as numeric user/group 10001 and contains no shell, package manager,
OpenSSL, zlib or libc runtime. Go performs TLS itself. This removes the old
Alpine package dependencies; it does not establish that the Go binary has no
vulnerabilities. Rescan the actual final image before promotion.

## Bounded build on the shared Oracle VM

Run from the repository root. A dedicated builder bounds the entire build to one
CPU and 2 GiB RAM; compiler concurrency and its soft memory target are bounded
inside the Dockerfile too. These commands have not been run on Oracle by this
source-preparation step.

```sh
docker buildx create --name unlabel-auth-build --driver docker-container \
  --driver-opt memory=2g,memory-swap=2g,cpu-period=100000,cpu-quota=100000
docker buildx build --builder unlabel-auth-build --platform linux/arm64 \
  --load --target runtime --file infrastructure/docker/auth.Dockerfile \
  --tag unlabel-auth:v2.197.0-unlabel.2 .
```

The Docker healthcheck executes `/healthcheck`; it needs no shell, curl or wget.
It contacts only the configured auth port on loopback, refuses redirects, accepts
only HTTP 200, ignores proxy environment settings and times out after three
seconds. Use the image's Docker healthcheck in Coolify, or configure the exact
`/healthcheck` command if that Coolify version supports custom command checks.
Do not replace it with a shell-based curl/wget fallback in this image.

## Evidence and remaining gates

The official tag/commit, source archive, toolchain checksum, image manifest and
patched module versions were verified on 15 November 2026. Dedicated healthcheck
tests and the upstream `internal/crypto` tests passed locally using Go 1.27.4.
The Linux ARM64 build passed, and ELF inspection confirmed AArch64 with no
dynamic-loader program header. The binary's Go build information confirms the
patched versions, Go 1.27.4 and `CGO_ENABLED=0`. `govulncheck` 1.9.0 still reports
the following three symbol-level findings; the image is **not vulnerability-free**:

| Advisory | Remaining dependency | Required exposure control |
| --- | --- | --- |
| [GO-2026-6909](https://pkg.go.dev/vuln/GO-2026-6909) | `crewjam/saml` 0.4.14, no fixed version recorded by Go's advisory | Keep `GOTRUE_SAML_ENABLED=false`; the private identity service's SSO/SAML routes are gated and the public API must not proxy them |
| [GO-2026-5004](https://pkg.go.dev/vuln/GO-2026-5004) | `pgx/v4` 4.18.2, unsupported major with no fixed version | Keep extended PostgreSQL protocol, explicitly `prefer_simple_protocol=false`; the advisory requires nondefault simple protocol and dollar-quoted SQL placeholder confusion |
| [GO-2026-4518](https://pkg.go.dev/vuln/GO-2026-4518) | `pgproto3/v2` 2.3.3, unsupported major with no fixed version | Restrict identity connections to the private trusted PostgreSQL server; the advisory requires malicious or compromised server responses |

These controls narrow applicability; they do not patch the remaining libraries.
Replacing or upgrading their upstream adapters remains a maintenance item. Do
not suppress these findings or label an untested deployment secure. The initial
binary check also detected fixed gRPC/OpenPGP findings; those disappeared after
the final locked dependency updates above. No scanner suppressions were added.

Before changing the live sign-in service, require the actual final image to
start against the private identity database, pass its healthcheck and image scan,
and preserve guest signup/refresh/logout/revocation, email verification/recovery,
Google ID-token sign-in and linked-account behavior. A successful compile or
unit test alone is not production auth or mail-delivery proof.
