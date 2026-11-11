-- V004 · Keeps updated_at truthful without relying on application code.
-- Rollback: 05_rollbacks/01_ddl/07_functions/U004__create_function_set_updated_at.sql
CREATE OR REPLACE FUNCTION customers.set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
