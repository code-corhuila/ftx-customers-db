-- V003 · refresh_token: the opaque refresh tokens of the administrator sessions.
--
-- Rules from 00-governance/security-policy.md ("Refresh Token") and auth-service.yaml:
--   * 7-day lifetime; stored hashed with BCrypt, never in clear.
--   * One use only: refreshing marks the token used and issues a new one in the same family.
--   * Presenting a token that was already used or revoked revokes the whole family.
-- The token given to the client is "<id>.<secret>": the id finds the row, the secret is
-- checked against token_hash. Without the id a BCrypt hash could not be looked up.
-- The foreign key stays inside this schema (Annex J.3.4 forbids only cross-domain keys).
-- Rollback: 05_rollbacks/01_ddl/03_tables/U003__create_refresh_token.sql
CREATE TABLE customers.refresh_token (
    id           uuid          NOT NULL DEFAULT gen_random_uuid(),
    user_id      uuid          NOT NULL,
    family_id    uuid          NOT NULL,
    token_hash   varchar(255)  NOT NULL,
    expires_at   timestamptz   NOT NULL,
    used_at      timestamptz,
    revoked_at   timestamptz,
    created_at   timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_refresh_token PRIMARY KEY (id),

    CONSTRAINT fk_refresh_token_user_account
        FOREIGN KEY (user_id) REFERENCES customers.user_account (id),

    CONSTRAINT chk_refresh_token_hash_bcrypt
        CHECK (token_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$'),

    CONSTRAINT chk_refresh_token_expiry
        CHECK (expires_at > created_at AND expires_at <= created_at + interval '7 days')
);

COMMENT ON TABLE  customers.refresh_token            IS 'Opaque refresh tokens of administrator sessions, one use each, rotated within a family.';
COMMENT ON COLUMN customers.refresh_token.family_id  IS 'All tokens issued from one login share it; reuse of a spent token revokes the family.';
COMMENT ON COLUMN customers.refresh_token.token_hash IS 'BCrypt hash of the secret part of the token.';
