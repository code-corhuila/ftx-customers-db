-- U004 · Reverts V004__create_function_set_updated_at.sql (U005 runs first: the trigger uses it).
DROP FUNCTION IF EXISTS customers.set_updated_at();
