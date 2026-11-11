-- V005 · Fires set_updated_at on every update of user_account.
-- Rollback: 05_rollbacks/01_ddl/09_triggers/U005__create_trigger_user_account_updated_at.sql
CREATE TRIGGER trg_user_account_updated_at
    BEFORE UPDATE ON customers.user_account
    FOR EACH ROW
    EXECUTE FUNCTION customers.set_updated_at();
