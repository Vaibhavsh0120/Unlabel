-- Apply as the identity database owner, after GoTrue's own migrations.
-- This schema is private; the scheduler gets EXECUTE only, never auth-table access.
CREATE SCHEMA auth_maintenance;
REVOKE ALL ON SCHEMA auth_maintenance FROM PUBLIC;

CREATE INDEX unlabel_inactive_guests_idx ON auth.users
    ((greatest(created_at, updated_at, last_sign_in_at)), id)
    WHERE is_anonymous IS TRUE;

CREATE TABLE auth_maintenance.runs (
    task text PRIMARY KEY CHECK (task = 'inactive_guests'),
    completed_at timestamptz NOT NULL,
    deleted_count integer NOT NULL CHECK (deleted_count BETWEEN 0 AND 100)
);
REVOKE ALL ON auth_maintenance.runs FROM PUBLIC;

CREATE FUNCTION auth_maintenance.prune_inactive_guests() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog
SET statement_timeout = '5s'
SET lock_timeout = '500ms'
AS $$
DECLARE
    candidate uuid;
    cutoff timestamptz := statement_timestamp() - interval '24 hours';
    removed integer := 0;
    changed integer;
BEGIN
    -- Concurrent scheduler replicas must not multiply cleanup work.
    IF NOT pg_try_advisory_xact_lock(842317225) THEN
        RETURN 0;
    END IF;
    FOR candidate IN
        SELECT u.id FROM auth.users AS u
        WHERE u.is_anonymous IS TRUE
          AND greatest(u.created_at, u.updated_at, u.last_sign_in_at) < cutoff
          AND nullif(u.email, '') IS NULL AND nullif(u.phone, '') IS NULL
          AND NOT EXISTS (SELECT 1 FROM auth.identities AS i WHERE i.user_id = u.id)
          AND NOT EXISTS (
              SELECT 1 FROM auth.sessions AS s WHERE s.user_id = u.id
              AND greatest(s.created_at, s.updated_at, s.refreshed_at) >= cutoff
          )
        ORDER BY greatest(u.created_at, u.updated_at, u.last_sign_in_at), u.id
        LIMIT 100 FOR UPDATE OF u SKIP LOCKED
    LOOP
        BEGIN
            -- Lock existing sessions before rechecking activity. A refresh in flight
            -- wins; a session or identity insert must first wait for the user lock.
            PERFORM s.id FROM auth.sessions AS s
                WHERE s.user_id = candidate FOR UPDATE NOWAIT;
            DELETE FROM auth.users AS u
            WHERE u.id = candidate AND u.is_anonymous IS TRUE
              AND greatest(u.created_at, u.updated_at, u.last_sign_in_at) < cutoff
              AND nullif(u.email, '') IS NULL AND nullif(u.phone, '') IS NULL
              AND NOT EXISTS (SELECT 1 FROM auth.identities AS i WHERE i.user_id = u.id)
              AND NOT EXISTS (
                  SELECT 1 FROM auth.sessions AS s WHERE s.user_id = u.id
                  AND greatest(s.created_at, s.updated_at, s.refreshed_at) >= cutoff
              );
            GET DIAGNOSTICS changed = ROW_COUNT;
            removed := removed + changed;
        EXCEPTION WHEN lock_not_available THEN
            CONTINUE;
        END;
    END LOOP;
    -- GoTrue's cascading foreign keys remove sessions and refresh tokens atomically.
    INSERT INTO auth_maintenance.runs(task, completed_at, deleted_count)
        VALUES ('inactive_guests', clock_timestamp(), removed)
    ON CONFLICT (task) DO UPDATE SET
        completed_at = excluded.completed_at, deleted_count = excluded.deleted_count;
    RETURN removed;
END;
$$;
REVOKE ALL ON FUNCTION auth_maintenance.prune_inactive_guests() FROM PUBLIC;

CREATE FUNCTION auth_maintenance.guest_cleanup_healthy() RETURNS boolean
LANGUAGE sql SECURITY DEFINER
SET search_path = pg_catalog
AS $$
    SELECT EXISTS (SELECT 1 FROM auth_maintenance.runs
        WHERE task = 'inactive_guests' AND completed_at > now() - interval '15 minutes');
$$;
REVOKE ALL ON FUNCTION auth_maintenance.guest_cleanup_healthy() FROM PUBLIC;
