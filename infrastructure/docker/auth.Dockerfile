# Stable Supabase Auth rebuilt with reviewed security dependency updates.
FROM golang:1.27.4-bookworm@sha256:4fa7c968ba93f1635670522dbb01a2c78150443e1385746924566079f36570ea AS build
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOMAXPROCS=1 GOMEMLIMIT=1500MiB
WORKDIR /src
RUN curl --fail --location --proto '=https' --tlsv1.2 \
      https://codeload.github.com/supabase/auth/tar.gz/4eee58f296d9698a1c2c0ae14d7a0b379c7622d3 \
      --output /tmp/auth.tar.gz \
    && echo 'dd5168b9f0bb294fa1e1d343c23b6bb5f68376f271d97dea897339b28fbd4b8d  /tmp/auth.tar.gz' | sha256sum --check \
    && tar --extract --gzip --file /tmp/auth.tar.gz --strip-components=1 \
    && rm /tmp/auth.tar.gz
COPY infrastructure/docker/auth-source/go.mod infrastructure/docker/auth-source/go.sum ./
RUN go mod download && go mod verify
RUN go test -mod=readonly -p 1 ./internal/crypto
RUN go build -mod=readonly -p 1 -trimpath -buildvcs=false \
      -ldflags '-s -w -X github.com/supabase/auth/internal/utilities.Version=v2.197.0-unlabel.1' \
      -o /out/auth .
COPY infrastructure/docker/auth-source/healthcheck.go /health/healthcheck.go
COPY infrastructure/docker/auth-source/healthcheck_test.go /health/healthcheck_test.go
RUN go test -mod=readonly -p 1 /health/healthcheck.go /health/healthcheck_test.go \
    && go build -mod=readonly -p 1 -trimpath -buildvcs=false -ldflags '-s -w' \
      -o /out/healthcheck /health/healthcheck.go

FROM scratch AS runtime
LABEL org.opencontainers.image.title="Unlabel identity service - Supabase Auth" \
      org.opencontainers.image.version="v2.197.0-unlabel.1" \
      org.opencontainers.image.source="https://github.com/supabase/auth" \
      org.opencontainers.image.revision="4eee58f296d9698a1c2c0ae14d7a0b379c7622d3" \
      org.opencontainers.image.licenses="MIT"
COPY --from=build /out/auth /usr/local/bin/auth
COPY --from=build /out/healthcheck /healthcheck
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /usr/local/go/lib/time/zoneinfo.zip /usr/share/zoneinfo.zip
COPY --from=build /src/migrations /usr/local/etc/auth/migrations
COPY --from=build /src/LICENSE /usr/share/licenses/supabase-auth/LICENSE
COPY --from=build /usr/local/go/LICENSE /usr/share/licenses/go/LICENSE
COPY infrastructure/docker/auth-source/provenance.json /usr/share/unlabel/auth-source.json
ENV GOTRUE_API_HOST=0.0.0.0 GOTRUE_API_PORT=9999 \
    GOTRUE_SAML_ENABLED=false \
    GOTRUE_DB_MIGRATIONS_PATH=/usr/local/etc/auth/migrations \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt ZONEINFO=/usr/share/zoneinfo.zip
WORKDIR /home/unlabel
USER 10001:10001
EXPOSE 9999
HEALTHCHECK --interval=15s --timeout=5s --start-period=45s --retries=5 CMD ["/healthcheck"]
ENTRYPOINT ["/usr/local/bin/auth"]
