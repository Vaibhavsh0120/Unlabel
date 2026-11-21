-- A targeted ON CONFLICT reads the arbiter columns, even for DO NOTHING.
-- Allow API deduplication without granting reads of job payloads or state.
GRANT SELECT(topic, idempotency_key) ON operations.outbox TO unlabel_api;
