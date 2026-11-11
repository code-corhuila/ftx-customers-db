-- U006 · Reverts V006__create_indexes.sql
DROP INDEX IF EXISTS customers.idx_refresh_token_family;
DROP INDEX IF EXISTS customers.idx_refresh_token_user_active;
DROP INDEX IF EXISTS customers.idx_user_account_email;
