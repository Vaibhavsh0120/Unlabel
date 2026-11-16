CREATE SCHEMA community;
REVOKE ALL ON SCHEMA community FROM PUBLIC;

CREATE TABLE community.revisions (
    revision_id varchar(64) PRIMARY KEY CHECK (revision_id ~ '^[a-f0-9]{64}$'),
    actor_id varchar(64) NOT NULL CHECK (actor_id ~ '^[a-f0-9]{64}$'),
    submission_id uuid NOT NULL,
    barcode varchar(14) CHECK (barcode ~ '^[0-9]{8,14}$'),
    content_sha256 varchar(64) NOT NULL CHECK (content_sha256 ~ '^[a-f0-9]{64}$'),
    factual_sha256 varchar(64) NOT NULL CHECK (factual_sha256 ~ '^[a-f0-9]{64}$'),
    request_json jsonb NOT NULL CHECK (jsonb_typeof(request_json)='object'
        AND octet_length(request_json::text)<=262144),
    status varchar(16) NOT NULL CHECK (status IN
        ('candidate','pending','provisional','approved','rejected','superseded')),
    submitted_at timestamptz NOT NULL,
    expires_at timestamptz,
    reviewed_at timestamptz,
    supersedes varchar(64)[] NOT NULL DEFAULT '{}' CHECK (cardinality(supersedes)<=8),
    superseded_by varchar(64),
    UNIQUE (actor_id,submission_id),
    CHECK ((status='provisional')=(expires_at IS NOT NULL)),
    CHECK (expires_at IS NULL OR expires_at>submitted_at),
    CHECK ((status IN ('approved','rejected','superseded'))=(reviewed_at IS NOT NULL)),
    CHECK (reviewed_at IS NULL OR reviewed_at>=submitted_at),
    CHECK ((status='superseded')=(superseded_by IS NOT NULL)),
    CHECK (status='provisional' OR barcode IS NOT NULL)
);
CREATE INDEX community_active ON community.revisions(barcode,submitted_at,revision_id)
    WHERE status IN ('candidate','approved');
CREATE INDEX community_pending ON community.revisions(submitted_at,revision_id)
    WHERE status='pending';
CREATE INDEX community_expiring ON community.revisions(expires_at,actor_id)
    WHERE status='provisional';

CREATE TABLE community.receipts (
    actor_id varchar(64) NOT NULL CHECK (actor_id ~ '^[a-f0-9]{64}$'),
    submission_id uuid NOT NULL,
    target_id varchar(64) NOT NULL REFERENCES community.revisions(revision_id) ON DELETE CASCADE,
    content_sha256 varchar(64) NOT NULL CHECK (content_sha256 ~ '^[a-f0-9]{64}$'),
    factual_sha256 varchar(64) NOT NULL CHECK (factual_sha256 ~ '^[a-f0-9]{64}$'),
    submitted_at timestamptz NOT NULL,
    warnings text[] NOT NULL CHECK (cardinality(warnings)<=100),
    PRIMARY KEY (actor_id,submission_id)
);
CREATE INDEX community_receipt_target ON community.receipts(target_id);

CREATE TABLE community.counters (
    key varchar(90) PRIMARY KEY,
    window_day date,
    count integer NOT NULL CHECK (count BETWEEN 1 AND 10000)
);
CREATE INDEX community_expiring_counters ON community.counters(window_day)
    WHERE window_day IS NOT NULL;

CREATE TABLE community.review_holds (barcode varchar(14) PRIMARY KEY);
CREATE TABLE community.review_audit (
    revision_id varchar(64) PRIMARY KEY REFERENCES community.revisions(revision_id),
    content_sha256 varchar(64) NOT NULL,
    decision varchar(8) NOT NULL CHECK (decision IN ('approve','reject')),
    reviewed_at timestamptz NOT NULL,
    supersedes varchar(64)[] NOT NULL
);

-- The projection receives a public evidence document, never receipts or owner keys.
CREATE TABLE community.publication (
    revision_id varchar(64) PRIMARY KEY REFERENCES community.revisions(revision_id),
    document jsonb NOT NULL CHECK (jsonb_typeof(document)='object'
        AND octet_length(document::text)<=524288),
    sha256 varchar(64) NOT NULL CHECK (sha256 ~ '^[a-f0-9]{64}$')
);
REVOKE ALL ON ALL TABLES IN SCHEMA community FROM PUBLIC;
GRANT USAGE ON SCHEMA community TO unlabel_api;
GRANT SELECT, INSERT ON community.revisions, community.receipts, community.publication TO unlabel_api;
GRANT UPDATE(status) ON community.revisions TO unlabel_api;
GRANT SELECT, INSERT, UPDATE(count) ON community.counters TO unlabel_api;
GRANT SELECT, INSERT ON community.review_holds TO unlabel_api;
ALTER TABLE operations.worker_heartbeats
    DROP CONSTRAINT worker_heartbeats_process_kind_check,
    ADD CHECK (process_kind IN ('worker','scheduler','evidence'));
