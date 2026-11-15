-- Dedicated notification workers must not steal source-import/evidence jobs.
CREATE INDEX outbox_topic_due ON operations.outbox(topic,available_at,id)
    WHERE state IN ('queued','leased');

CREATE FUNCTION operations.claim_topic_jobs(p_worker uuid, p_topic varchar, p_limit integer DEFAULT 1)
RETURNS SETOF operations.outbox LANGUAGE sql SECURITY INVOKER
SET search_path = pg_catalog, operations AS $$
    WITH due AS (
        SELECT id FROM operations.outbox
        WHERE p_worker IS NOT NULL AND p_limit BETWEEN 1 AND 10
          AND topic = p_topic AND attempts < max_attempts
          AND ((state='queued' AND available_at <= now())
            OR (state='leased' AND lease_expires_at <= now()))
        ORDER BY available_at,id LIMIT greatest(0,least(p_limit,10))
        FOR UPDATE SKIP LOCKED
    )
    UPDATE operations.outbox AS job SET state='leased',attempts=attempts+1,
        lease_owner=p_worker,lease_token=gen_random_uuid(),
        lease_expires_at=now()+interval '2 minutes'
    FROM due WHERE job.id=due.id RETURNING job.*;
$$;

CREATE FUNCTION operations.enqueue_daily_reminders(p_now timestamptz) RETURNS bigint
LANGUAGE sql SECURITY INVOKER SET search_path = pg_catalog, operations AS $$
    WITH clock AS (SELECT (p_now AT TIME ZONE 'UTC')::date AS day,
        (p_now AT TIME ZONE 'UTC')::time AS time), due AS (
        SELECT s.id, clock.day FROM operations.push_subscriptions AS s CROSS JOIN clock
        WHERE s.enabled AND clock.time >= time '13:30:00'
          AND (s.last_delivered_day IS NULL OR s.last_delivered_day < clock.day)
          AND NOT EXISTS (SELECT 1 FROM operations.outbox AS j
              WHERE j.topic='notifications.deliver'
                AND j.idempotency_key='reminder:'||clock.day::text||':'||s.id)
        ORDER BY s.id LIMIT 500
    ), queued AS (
        INSERT INTO operations.outbox(topic,idempotency_key,payload)
        SELECT 'notifications.deliver','reminder:'||day::text||':'||id,
            jsonb_build_object('reference',id) FROM due
        ON CONFLICT(topic,idempotency_key) DO NOTHING RETURNING id
    ) SELECT count(*) FROM queued;
$$;

-- Scheduler can enqueue current reminders without reading subscription keys or
-- accessing the outbox directly. The parameterized implementation stays private.
CREATE FUNCTION operations.enqueue_daily_reminders() RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, operations, pg_temp AS $$
    SELECT operations.enqueue_daily_reminders(now());
$$;

CREATE FUNCTION operations.prune_finished_jobs() RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, operations, pg_temp AS $$
    WITH expired AS (
        SELECT id FROM operations.outbox WHERE
            (state='completed' AND completed_at < now()-interval '7 days') OR
            (state='dead' AND available_at < now()-interval '30 days')
        ORDER BY created_at,id LIMIT 500 FOR UPDATE SKIP LOCKED
    ), removed AS (
        DELETE FROM operations.outbox WHERE id IN (SELECT id FROM expired) RETURNING id
    ) SELECT count(*) FROM removed;
$$;

REVOKE ALL ON FUNCTION operations.claim_topic_jobs(uuid,varchar,integer),
    operations.enqueue_daily_reminders(timestamptz), operations.enqueue_daily_reminders(),
    operations.prune_finished_jobs() FROM PUBLIC;
