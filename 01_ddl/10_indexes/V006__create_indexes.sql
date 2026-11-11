-- V006 · Indexes of the customers domain.
-- idx_user_account_email
--   * Rule: administrator emails are unique (data-dictionary.md). The email is stored
--     normalised (CHECK in V002), so a plain unique index is enough.
--   * Also serves the login lookup by email.
-- idx_refresh_token_user_active
--   * Serves logout with allDevices = true: the active tokens of one administrator.
-- idx_refresh_token_family
--   * Serves the reuse rule: revoke every token of a family at once.
-- The tables are empty when this runs, so CONCURRENTLY is not needed (Annex A, rule 14).
-- Rollback: 05_rollbacks/01_ddl/10_indexes/U006__create_indexes.sql
CREATE UNIQUE INDEX idx_user_account_email
    ON customers.user_account (email);

CREATE INDEX idx_refresh_token_user_active
    ON customers.refresh_token (user_id)
    WHERE revoked_at IS NULL AND used_at IS NULL;

CREATE INDEX idx_refresh_token_family
    ON customers.refresh_token (family_id);
