-- Next major only. Not invoked by the 0.16.0 runtime or its deployment.
-- Apply once with the dedicated migration role, inside a recorded migration run.
CREATE SCHEMA accounts;
CREATE SCHEMA catalogue;
CREATE SCHEMA operations;
REVOKE ALL ON SCHEMA accounts, catalogue, operations FROM PUBLIC;

CREATE TABLE accounts.users (
    id uuid PRIMARY KEY,
    auth_subject uuid NOT NULL UNIQUE,
    owner_hash char(64) NOT NULL UNIQUE CHECK (owner_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE accounts.profiles (
    owner_id uuid PRIMARY KEY REFERENCES accounts.users(id),
    display_name varchar(160),
    gender varchar(16) NOT NULL DEFAULT 'unset'
        CHECK (gender IN ('unset', 'male', 'female')),
    avatar_png bytea CHECK (octet_length(avatar_png) <= 98304),
    avatar_source varchar(16) NOT NULL DEFAULT 'default'
        CHECK (avatar_source IN ('default', 'google', 'custom')),
    revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE accounts.library_snapshots (
    owner_id uuid PRIMARY KEY REFERENCES accounts.users(id),
    revision bigint NOT NULL CHECK (revision >= 1),
    mutation_id uuid NOT NULL,
    expected_revision bigint NOT NULL CHECK (expected_revision = revision - 1),
    payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'
        AND octet_length(payload::text) <= 524288),
    payload_sha256 char(64) NOT NULL CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Retain only the permanent pseudonymous marker after owner-data deletion.
CREATE TABLE accounts.deletion_markers (
    owner_hash char(64) PRIMARY KEY CHECK (owner_hash ~ '^[0-9a-f]{64}$'),
    deleted_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE catalogue.source_bundles (
    sha256 char(64) PRIMARY KEY CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    source_url text NOT NULL,
    exported_at timestamptz NOT NULL,
    indexed_products integer NOT NULL CHECK (indexed_products >= 0),
    license_id text NOT NULL,
    receipt jsonb NOT NULL CHECK (jsonb_typeof(receipt) = 'object'),
    imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE catalogue.products (
    barcode varchar(14) PRIMARY KEY CHECK (barcode ~ '^([0-9]{8}|[0-9]{12,14})$'),
    bundle_sha256 char(64) NOT NULL REFERENCES catalogue.source_bundles(sha256),
    source_id text NOT NULL UNIQUE,
    identity jsonb NOT NULL CHECK (jsonb_typeof(identity) = 'object'),
    facts jsonb NOT NULL CHECK (jsonb_typeof(facts) = 'object'),
    normalized_identity text NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS
        (to_tsvector('simple', normalized_identity)) STORED
);
CREATE INDEX products_search_gin ON catalogue.products USING gin(search_vector);

-- Images remain provenance-linked descriptors, never bundled product bytes.
CREATE TABLE catalogue.image_descriptors (
    descriptor_id char(64) PRIMARY KEY CHECK (descriptor_id ~ '^[0-9a-f]{64}$'),
    barcode varchar(14),
    url text NOT NULL CHECK (url LIKE 'https://%'),
    source_reference jsonb NOT NULL CHECK (jsonb_typeof(source_reference) = 'object'),
    retrieved_at timestamptz NOT NULL
);

CREATE TABLE operations.outbox (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    topic varchar(64) NOT NULL CHECK
        (topic IN ('catalogue.import', 'evidence.project', 'notifications.deliver')),
    idempotency_key varchar(160) NOT NULL,
    payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'
        AND payload ? 'reference' AND payload - 'reference' = '{}'::jsonb
        AND jsonb_typeof(payload->'reference') = 'string'
        AND length(payload->>'reference') BETWEEN 1 AND 160),
    state varchar(16) NOT NULL DEFAULT 'queued'
        CHECK (state IN ('queued', 'leased', 'completed', 'dead')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    max_attempts integer NOT NULL DEFAULT 5 CHECK (max_attempts BETWEEN 1 AND 10),
    available_at timestamptz NOT NULL DEFAULT now(),
    lease_owner uuid,
    lease_token uuid,
    lease_expires_at timestamptz,
    error_code varchar(64) CHECK (error_code ~ '^[a-z][a-z0-9_]{0,63}$'),
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    UNIQUE (topic, idempotency_key),
    CHECK (attempts <= max_attempts),
    CHECK ((state = 'leased' AND lease_owner IS NOT NULL AND lease_token IS NOT NULL
        AND lease_expires_at IS NOT NULL) OR (state <> 'leased' AND lease_owner IS NULL
        AND lease_token IS NULL AND lease_expires_at IS NULL)),
    CHECK ((state = 'completed') = (completed_at IS NOT NULL))
);
CREATE INDEX outbox_due ON operations.outbox(available_at, id)
    WHERE state IN ('queued', 'leased');

-- SKIP LOCKED permits independent workers; token-checked acknowledgement fences
-- a slow worker after its lease expires and another worker has taken ownership.
CREATE FUNCTION operations.claim_jobs(p_worker uuid, p_limit integer DEFAULT 10)
RETURNS SETOF operations.outbox LANGUAGE sql SECURITY INVOKER
SET search_path = pg_catalog, operations AS $$
    WITH due AS (
        SELECT id FROM operations.outbox
        WHERE p_worker IS NOT NULL AND p_limit BETWEEN 1 AND 50
          AND attempts < max_attempts
          AND ((state = 'queued' AND available_at <= now())
            OR (state = 'leased' AND lease_expires_at <= now()))
        ORDER BY available_at, id
        LIMIT greatest(0, least(p_limit, 50))
        FOR UPDATE SKIP LOCKED
    )
    UPDATE operations.outbox AS job SET state = 'leased', attempts = attempts + 1,
        lease_owner = p_worker, lease_token = gen_random_uuid(),
        lease_expires_at = now() + interval '2 minutes'
    FROM due WHERE job.id = due.id RETURNING job.*;
$$;

CREATE FUNCTION operations.complete_job(p_id uuid, p_worker uuid, p_token uuid)
RETURNS boolean LANGUAGE sql SECURITY INVOKER
SET search_path = pg_catalog, operations AS $$
    WITH completed AS (
        UPDATE operations.outbox SET state = 'completed', completed_at = now(),
            lease_owner = NULL, lease_token = NULL, lease_expires_at = NULL
        WHERE id = p_id AND state = 'leased' AND lease_owner = p_worker
          AND lease_token = p_token AND lease_expires_at > now()
        RETURNING id
    ) SELECT EXISTS (SELECT 1 FROM completed);
$$;

CREATE FUNCTION operations.fail_job(p_id uuid, p_worker uuid, p_token uuid, p_error varchar)
RETURNS boolean LANGUAGE sql SECURITY INVOKER
SET search_path = pg_catalog, operations AS $$
    WITH failed AS (
        UPDATE operations.outbox SET
            state = CASE WHEN attempts >= max_attempts THEN 'dead' ELSE 'queued' END,
            available_at = now() + make_interval(secs => least(3600, 10 * (2 ^ attempts)::int)),
            error_code = p_error, lease_owner = NULL, lease_token = NULL, lease_expires_at = NULL
        WHERE id = p_id AND state = 'leased' AND lease_owner = p_worker
          AND lease_token = p_token AND lease_expires_at > now()
          AND p_error ~ '^[a-z][a-z0-9_]{0,63}$'
        RETURNING id
    ) SELECT EXISTS (SELECT 1 FROM failed);
$$;

CREATE FUNCTION operations.renew_job(p_id uuid, p_worker uuid, p_token uuid)
RETURNS boolean LANGUAGE sql SECURITY INVOKER
SET search_path = pg_catalog, operations AS $$
    WITH renewed AS (
        UPDATE operations.outbox SET lease_expires_at = now() + interval '2 minutes'
        WHERE id = p_id AND state = 'leased' AND lease_owner = p_worker
          AND lease_token = p_token AND lease_expires_at > now()
        RETURNING id
    ) SELECT EXISTS (SELECT 1 FROM renewed);
$$;

CREATE FUNCTION operations.reap_exhausted()
RETURNS bigint LANGUAGE sql SECURITY INVOKER
SET search_path = pg_catalog, operations AS $$
    WITH expired AS (
        SELECT id FROM operations.outbox
        WHERE attempts >= max_attempts AND state = 'leased' AND lease_expires_at <= now()
        ORDER BY lease_expires_at, id LIMIT 100 FOR UPDATE SKIP LOCKED
    ), dead AS (
        UPDATE operations.outbox SET state = 'dead', error_code = 'lease_exhausted',
            lease_owner = NULL, lease_token = NULL, lease_expires_at = NULL
        FROM expired WHERE operations.outbox.id = expired.id RETURNING operations.outbox.id
    ) SELECT count(*) FROM dead;
$$;

REVOKE ALL ON ALL TABLES IN SCHEMA accounts, catalogue, operations FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA operations FROM PUBLIC;
