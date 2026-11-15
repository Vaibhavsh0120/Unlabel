-- API-only grants. The application derives ownership from a verified identity;
-- no client receives this database login or direct table access.
GRANT USAGE ON SCHEMA accounts, operations TO unlabel_api;
GRANT SELECT, INSERT, DELETE ON accounts.users TO unlabel_api;
GRANT UPDATE(deleted_at) ON accounts.users TO unlabel_api;
GRANT SELECT, INSERT ON accounts.deletion_markers TO unlabel_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts.profiles, accounts.library_snapshots TO unlabel_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON operations.push_subscriptions TO unlabel_api;
GRANT INSERT ON operations.outbox TO unlabel_api;
