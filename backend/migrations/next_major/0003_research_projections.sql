CREATE TABLE catalogue.research_datasets (
    sha256 char(64) PRIMARY KEY CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    receipt jsonb NOT NULL CHECK (jsonb_typeof(receipt) = 'object')
);
CREATE TABLE catalogue.research_search (
    entry_id char(64) NOT NULL CHECK (entry_id ~ '^[0-9a-f]{64}$'),
    dataset_sha256 char(64) NOT NULL REFERENCES catalogue.research_datasets(sha256),
    eligible_barcode varchar(14),
    name_sort text NOT NULL,
    tokens text[] NOT NULL,
    conflict_fields text[] NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (array_to_tsvector(tokens)) STORED,
    PRIMARY KEY (dataset_sha256,entry_id)
);
CREATE INDEX research_vector_gin ON catalogue.research_search USING gin(search_vector);
CREATE INDEX research_barcode ON catalogue.research_search(dataset_sha256,eligible_barcode);
CREATE INDEX research_order ON catalogue.research_search(dataset_sha256,name_sort,entry_id);
REVOKE ALL ON ALL TABLES IN SCHEMA catalogue FROM PUBLIC;
