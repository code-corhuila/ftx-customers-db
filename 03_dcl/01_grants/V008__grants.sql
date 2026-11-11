-- V008 · Permissions of the customers domain.
--   customers_reader: read only, and never the hashes (column-level grant): a reader such as a
--                     report or an audit tool has no use for password or token hashes.
--   customers_writer: what ftx-customers-api needs and nothing more:
--                     user_account  SELECT, INSERT (first administrator at start-up),
--                                   UPDATE (failed logins, lockout).
--                     refresh_token SELECT, INSERT (login, refresh), UPDATE (use, revoke).
--                     Never DELETE, never DDL.
-- The domain grants its writer role to its own user (Annex J.7). customers_app is created by
-- ftx-infra-postgres; if it does not exist yet (for example in CI with an empty database), the
-- grant is skipped.
-- Rollback: 05_rollbacks/03_dcl/01_grants/U008__grants.sql
GRANT USAGE ON SCHEMA customers TO customers_reader, customers_writer;

-- Table by table, never ON ALL TABLES: the schema also holds flyway_schema_history,
-- and no application user may read or alter the migration history.
GRANT SELECT (id, full_name, email, phone, role, failed_login_count, locked_until, created_at, updated_at)
    ON customers.user_account TO customers_reader;
GRANT SELECT (id, user_id, family_id, expires_at, used_at, revoked_at, created_at)
    ON customers.refresh_token TO customers_reader;

GRANT SELECT, INSERT, UPDATE ON customers.user_account  TO customers_writer;
GRANT SELECT, INSERT, UPDATE ON customers.refresh_token TO customers_writer;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'customers_app') THEN
        GRANT customers_writer TO customers_app;
    ELSE
        RAISE NOTICE 'customers_app does not exist yet: grant skipped (created by ftx-infra-postgres)';
    END IF;
END
$$;
