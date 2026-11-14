-- Initial GoTrue provisioning wrote its 75 embedded migration receipts in public
-- before the identity role's auth,public search_path was installed. All actual
-- GoTrue tables were created in auth. A restart then saw only replayed receipts
-- in auth and tried to recreate an obsolete oauth_clients.client_id index.
-- Move only this verified, version-specific receipt set; never replay old DDL.
DO $$
BEGIN
    IF to_regclass('public.schema_migrations') IS NOT NULL THEN
        IF (SELECT count(*) FROM public.schema_migrations) <> 75
            OR (SELECT max(version) FROM public.schema_migrations) <> '20260831180000'
        THEN
            RAISE EXCEPTION 'Unexpected GoTrue bootstrap receipt set; inspect before alignment';
        END IF;
        INSERT INTO auth.schema_migrations(version)
            SELECT version FROM public.schema_migrations
            ON CONFLICT (version) DO NOTHING;
        DROP TABLE public.schema_migrations;
    END IF;
END;
$$;
