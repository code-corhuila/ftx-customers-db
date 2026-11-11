-- U008 · Reverts V008__grants.sql
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'customers_app') THEN
        REVOKE customers_writer FROM customers_app;
    END IF;
END
$$;

REVOKE ALL ON customers.refresh_token FROM customers_writer, customers_reader;
REVOKE ALL ON customers.user_account  FROM customers_writer, customers_reader;
REVOKE USAGE ON SCHEMA customers FROM customers_reader, customers_writer;
