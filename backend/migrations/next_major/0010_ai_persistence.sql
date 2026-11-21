CREATE SCHEMA ai;
REVOKE ALL ON SCHEMA ai FROM PUBLIC;

-- Fixed selection, quota and staging keys retain the original storage bounds.
-- Product pointers are bounded by the 4,000 lifetime observation allowance.
CREATE TABLE ai.documents (
    collection varchar(40) NOT NULL,
    key varchar(48) NOT NULL,
    value jsonb NOT NULL CHECK (jsonb_typeof(value)='object'
        AND octet_length(value::text)<=524288),
    PRIMARY KEY(collection,key),
    CHECK (
        (collection='unlabel_service_configuration' AND key='ai-active') OR
        (collection='unlabel_ai_limits' AND key ~ '^(global|actor-[0-9a-f]{2})$') OR
        (collection='unlabel_machine_staging' AND key ~ '^[0-9a-f]{2}$') OR
        (collection='unlabel_machine_products' AND key ~ '^([0-9]{8}|[0-9]{12,14})$') OR
        (collection='unlabel_machine_limits' AND key='lifetime')
    )
);
CREATE TABLE ai.observations (
    id varchar(64) PRIMARY KEY CHECK (id ~ '^[0-9a-f]{64}$'),
    value jsonb NOT NULL CHECK (jsonb_typeof(value)='object'
        AND octet_length(value::text)<=98304)
);
REVOKE ALL ON ALL TABLES IN SCHEMA ai FROM PUBLIC;
GRANT USAGE ON SCHEMA ai TO unlabel_api;
GRANT SELECT,INSERT,UPDATE(value) ON ai.documents TO unlabel_api;
GRANT SELECT,INSERT ON ai.observations TO unlabel_api;

-- Link existing permanent deletion markers to the separate AI actor namespace.
-- The same AI lock protects deletion and in-flight private staging completion.
ALTER TABLE accounts.deletion_markers ADD COLUMN actor_hash char(64)
    CHECK (actor_hash ~ '^[0-9a-f]{64}$');
CREATE UNIQUE INDEX deleted_actor_hash ON accounts.deletion_markers(actor_hash)
    WHERE actor_hash IS NOT NULL;
GRANT UPDATE(actor_hash) ON accounts.deletion_markers TO unlabel_api;
