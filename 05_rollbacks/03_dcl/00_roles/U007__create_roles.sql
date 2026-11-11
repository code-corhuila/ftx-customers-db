-- U007 · Reverts V007__create_roles.sql (U008 runs first: a role with grants cannot be dropped).
DROP ROLE IF EXISTS customers_writer;
DROP ROLE IF EXISTS customers_reader;
