-- U001 · Reverts V001__create_schema_customers.sql
-- RESTRICT on purpose: if anything is left in the schema, this fails and shows
-- that a previous rollback is missing. Delete customers.flyway_schema_history
-- before running it (Annex J.6).
DROP SCHEMA IF EXISTS customers RESTRICT;
