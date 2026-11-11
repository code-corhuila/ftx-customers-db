-- V002 · user_account: the administrator accounts (HU-ADM-002).
--
-- Source model: ftx-docs 06-data/data-dictionary.md, section "2. user-service", table "users",
-- adapted to the norm:
--   * Singular snake_case name (Annex A, rule 1). "user" is a reserved word in PostgreSQL,
--     so the table is user_account.
--   * Closed sets of values are CHECK constraints, never ENUM (Annex A, rule 5).
--   * Constraints have explicit names (Annex A, rule 4).
--   * The unique index on the email lives in 10_indexes (V006).
-- Two columns are added to the model for the lockout rule of 00-governance/security-rules.md
-- (A07: "account lockout after 5 consecutive failed attempts"): failed_login_count and
-- locked_until.
-- No row is seeded: an administrator with a fixed, versioned credential is forbidden. The first
-- administrator is created by ftx-customers-api at start-up from deployment variables.
-- Rollback: 05_rollbacks/01_ddl/03_tables/U002__create_user_account.sql
CREATE TABLE customers.user_account (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    full_name           varchar(150)  NOT NULL,
    email               varchar(255)  NOT NULL,
    password_hash       varchar(255)  NOT NULL,
    phone               varchar(30),
    role                text          NOT NULL DEFAULT 'ADMINISTRATOR',
    failed_login_count  integer       NOT NULL DEFAULT 0,
    locked_until        timestamptz,
    created_at          timestamptz   NOT NULL DEFAULT now(),
    updated_at          timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_user_account PRIMARY KEY (id),

    CONSTRAINT chk_user_account_full_name_not_blank
        CHECK (length(btrim(full_name)) > 0),

    -- Stored normalised, so the unique index and the login lookup agree.
    CONSTRAINT chk_user_account_email_normalised
        CHECK (email = lower(btrim(email)) AND email LIKE '_%@_%'),

    -- Only BCrypt hashes ($2a$, $2b$ or $2y$, 60 characters): a plain password cannot be stored.
    CONSTRAINT chk_user_account_password_hash_bcrypt
        CHECK (password_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$'),

    CONSTRAINT chk_user_account_role
        CHECK (role IN ('ADMINISTRATOR')),

    CONSTRAINT chk_user_account_failed_login_count
        CHECK (failed_login_count >= 0)
);

COMMENT ON TABLE  customers.user_account                    IS 'Administrator accounts of Futbolix. Customers have no account in the MVP.';
COMMENT ON COLUMN customers.user_account.password_hash      IS 'BCrypt hash, strength 12 or more (00-governance/security-rules.md, A02). Never a plain password.';
COMMENT ON COLUMN customers.user_account.failed_login_count IS 'Consecutive failed logins; reset to 0 on a successful login.';
COMMENT ON COLUMN customers.user_account.locked_until       IS 'Login is refused until this instant after 5 consecutive failures (security-rules.md, A07).';
