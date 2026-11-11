-- V001 · Schema of the customers domain.
-- ADR-012 (ftx-docs): ftx-customers-* hosts the documented user-service (Identity & Access):
-- the administrator accounts and their sessions. Customers still have no account
-- (01-context/scope.md, assumption 3); their contact data stays in the reservations domain.
-- Annex J.4: every domain lives in its own schema inside the single PostgreSQL
-- instance defined in ftx-infra-postgres. Nothing of this domain lives in public.
-- Rollback: 05_rollbacks/01_ddl/01_schemas/U001__create_schema_customers.sql
CREATE SCHEMA IF NOT EXISTS customers;
