-- U005 · Reverts V005__create_trigger_user_account_updated_at.sql
DROP TRIGGER IF EXISTS trg_user_account_updated_at ON customers.user_account;
