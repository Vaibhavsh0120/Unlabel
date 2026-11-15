ALTER TABLE catalogue.products DROP COLUMN search_vector;
ALTER TABLE catalogue.products ADD COLUMN search_tokens text[] NOT NULL DEFAULT '{}';
ALTER TABLE catalogue.products ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (array_to_tsvector(search_tokens)) STORED;
CREATE INDEX products_search_gin ON catalogue.products USING gin(search_vector);

CREATE TABLE catalogue.active_snapshot (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    bundle_sha256 char(64) NOT NULL REFERENCES catalogue.source_bundles(sha256)
);
CREATE TABLE catalogue.dataset_receipts (
    dataset_id varchar(64) PRIMARY KEY,
    source_sha256 char(64) NOT NULL CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    item_count integer NOT NULL CHECK (item_count >= 0),
    receipt jsonb NOT NULL CHECK (jsonb_typeof(receipt) = 'object'),
    imported_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE operations.push_subscriptions (
    id char(64) PRIMARY KEY CHECK (id ~ '^[0-9a-f]{64}$'),
    owner_hash char(64) NOT NULL CHECK (owner_hash ~ '^[0-9a-f]{64}$'),
    subscription jsonb NOT NULL CHECK (jsonb_typeof(subscription) = 'object'),
    enabled boolean NOT NULL DEFAULT true,
    last_test_at timestamptz,
    last_delivered_day date,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX subscriptions_owner ON operations.push_subscriptions(owner_hash);
CREATE TABLE operations.worker_heartbeats (
    worker_id uuid PRIMARY KEY,
    process_kind varchar(32) NOT NULL CHECK (process_kind IN ('worker', 'scheduler')),
    seen_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON ALL TABLES IN SCHEMA catalogue, operations FROM PUBLIC;
