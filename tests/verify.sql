-- =============================================================================
-- ftx-customers-db · Post-migration checks (run by db-ci.yml after migrate)
--
-- Every failed check raises an exception, so psql (ON_ERROR_STOP=1) exits
-- non-zero and the CI turns red. Test rows are rolled back (SQLSTATE P0099), so the
-- database is left exactly as the migrations created it.
-- The hash used below is a syntactically valid BCrypt string of 53 'a' characters: it is
-- not the hash of any password and never stays in the database.
-- =============================================================================

-- 1. No administrator is seeded: an administrator with a fixed, versioned credential is forbidden.
DO $$
BEGIN
    IF (SELECT count(*) FROM customers.user_account) <> 0 THEN
        RAISE EXCEPTION 'FAIL the migrations seeded an administrator';
    END IF;
    RAISE NOTICE 'OK  no seeded administrator';
END $$;

-- 2. A valid administrator and a valid refresh token are accepted; updated_at is maintained.
DO $$
DECLARE uid uuid; after_ts timestamptz;
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash)
    VALUES ('Verify Admin', 'verify@example.test', '$2a$12$' || repeat('a', 53))
    RETURNING id INTO uid;
    INSERT INTO customers.refresh_token (user_id, family_id, token_hash, expires_at)
    VALUES (uid, gen_random_uuid(), '$2a$12$' || repeat('a', 53), now() + interval '7 days');
    UPDATE customers.user_account SET updated_at = now() - interval '1 day', failed_login_count = 1
     WHERE id = uid RETURNING updated_at INTO after_ts;
    IF after_ts < now() THEN
        RAISE EXCEPTION 'FAIL updated_at trigger did not fire';
    END IF;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN
    RAISE NOTICE 'OK  valid administrator and refresh token accepted, updated_at refreshed (rolled back)';
END $$;

-- 3. A plain password is rejected: only BCrypt hashes fit.
DO $$
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash)
    VALUES ('Verify Admin', 'plain@example.test', 'not-a-hash-but-a-password');
    RAISE EXCEPTION 'FAIL a plain password was stored';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  plain password rejected';
END $$;

-- 4. Emails are unique and stored normalised.
DO $$
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash)
    VALUES ('Verify Admin', 'Upper@Example.test', '$2a$12$' || repeat('a', 53));
    RAISE EXCEPTION 'FAIL an email with upper case was stored';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  non-normalised email rejected';
END $$;

DO $$
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash)
    VALUES ('Verify A', 'dup@example.test', '$2a$12$' || repeat('a', 53)),
           ('Verify B', 'dup@example.test', '$2a$12$' || repeat('a', 53));
    RAISE EXCEPTION 'FAIL a duplicate email was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK  duplicate email rejected';
END $$;

-- 5. Only the ADMINISTRATOR role, a non-blank name and a non-negative failure counter.
DO $$
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash, role)
    VALUES ('Verify Admin', 'role@example.test', '$2a$12$' || repeat('a', 53), 'CUSTOMER');
    RAISE EXCEPTION 'FAIL an unknown role was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  unknown role rejected';
END $$;

DO $$
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash)
    VALUES ('   ', 'blank@example.test', '$2a$12$' || repeat('a', 53));
    RAISE EXCEPTION 'FAIL a blank name was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  blank name rejected';
END $$;

DO $$
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash, failed_login_count)
    VALUES ('Verify Admin', 'count@example.test', '$2a$12$' || repeat('a', 53), -1);
    RAISE EXCEPTION 'FAIL a negative failure counter was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  negative failure counter rejected';
END $$;

-- 6. A refresh token cannot live more than 7 days, cannot be stored in clear,
--    and must belong to an existing administrator.
DO $$
DECLARE uid uuid;
BEGIN
    INSERT INTO customers.user_account (full_name, email, password_hash)
    VALUES ('Verify Admin', 'ttl@example.test', '$2a$12$' || repeat('a', 53)) RETURNING id INTO uid;
    BEGIN
        INSERT INTO customers.refresh_token (user_id, family_id, token_hash, expires_at)
        VALUES (uid, gen_random_uuid(), '$2a$12$' || repeat('a', 53), now() + interval '8 days');
        RAISE EXCEPTION 'FAIL a refresh token of 8 days was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK  refresh token longer than 7 days rejected';
    END;
    BEGIN
        INSERT INTO customers.refresh_token (user_id, family_id, token_hash, expires_at)
        VALUES (uid, gen_random_uuid(), 'clear-token', now() + interval '1 day');
        RAISE EXCEPTION 'FAIL a refresh token in clear was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK  refresh token in clear rejected';
    END;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN
    NULL;
END $$;

DO $$
BEGIN
    INSERT INTO customers.refresh_token (user_id, family_id, token_hash, expires_at)
    VALUES (gen_random_uuid(), gen_random_uuid(), '$2a$12$' || repeat('a', 53), now() + interval '1 day');
    RAISE EXCEPTION 'FAIL a refresh token without administrator was accepted';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK  refresh token of an unknown administrator rejected';
END $$;

-- 7. The only foreign key stays inside the schema (Annex J.3.4).
DO $$
BEGIN
    IF EXISTS (SELECT 1
                 FROM pg_constraint c
                 JOIN pg_class t  ON t.oid = c.conrelid
                 JOIN pg_namespace n  ON n.oid = t.relnamespace
                 JOIN pg_class rt ON rt.oid = c.confrelid
                 JOIN pg_namespace rn ON rn.oid = rt.relnamespace
                WHERE c.contype = 'f' AND n.nspname = 'customers' AND rn.nspname <> 'customers') THEN
        RAISE EXCEPTION 'FAIL the customers schema references another schema';
    END IF;
    RAISE NOTICE 'OK  no cross-domain foreign key';
END $$;

-- 8. Nothing of this domain lives in public (Annex A, rule 9).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public'
                AND (tablename LIKE '%user%' OR tablename LIKE '%token%')) THEN
        RAISE EXCEPTION 'FAIL a customers table lives in public';
    END IF;
    RAISE NOTICE 'OK  nothing in public';
END $$;

-- 9. Roles exist, cannot log in, and follow least privilege.
DO $$
BEGIN
    IF (SELECT count(*) FROM pg_roles
         WHERE rolname IN ('customers_reader', 'customers_writer') AND NOT rolcanlogin) <> 2 THEN
        RAISE EXCEPTION 'FAIL customers_reader / customers_writer missing or LOGIN';
    END IF;
    IF NOT has_column_privilege('customers_reader', 'customers.user_account', 'email', 'SELECT')
       OR has_column_privilege('customers_reader', 'customers.user_account', 'password_hash', 'SELECT')
       OR has_column_privilege('customers_reader', 'customers.refresh_token', 'token_hash', 'SELECT')
       OR has_table_privilege('customers_reader', 'customers.user_account', 'UPDATE') THEN
        RAISE EXCEPTION 'FAIL customers_reader must read, never the hashes, and never write';
    END IF;
    IF NOT has_table_privilege('customers_writer', 'customers.user_account', 'INSERT')
       OR NOT has_table_privilege('customers_writer', 'customers.user_account', 'UPDATE')
       OR NOT has_table_privilege('customers_writer', 'customers.refresh_token', 'INSERT')
       OR NOT has_table_privilege('customers_writer', 'customers.refresh_token', 'UPDATE')
       OR has_table_privilege('customers_writer', 'customers.user_account', 'DELETE')
       OR has_table_privilege('customers_writer', 'customers.refresh_token', 'DELETE')
       OR has_schema_privilege('customers_writer', 'customers', 'CREATE') THEN
        RAISE EXCEPTION 'FAIL customers_writer must insert and update, never delete or create objects';
    END IF;
    RAISE NOTICE 'OK  roles NOLOGIN with least privilege (no DELETE, no DDL, reader without hashes)';
END $$;

-- 10. No application role can touch the migration history.
DO $$
BEGIN
    IF to_regclass('customers.flyway_schema_history') IS NOT NULL
       AND (has_table_privilege('customers_writer', 'customers.flyway_schema_history', 'SELECT')
         OR has_table_privilege('customers_reader', 'customers.flyway_schema_history', 'SELECT')) THEN
        RAISE EXCEPTION 'FAIL an application role can read flyway_schema_history';
    END IF;
    RAISE NOTICE 'OK  migration history is private';
END $$;
