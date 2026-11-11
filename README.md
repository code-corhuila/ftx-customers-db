# ftx-customers-db

> Customers domain: administrator accounts, refresh tokens, roles and Flyway migrations

Part of **Futbolix**, the distributed system for reserving the four football courts of a
single sports facility. Governance and documentation live in
[`ftx-docs`](https://github.com/code-corhuila/ftx-docs). User story: HU-ADM-002 (Administrator
Login).

## What this domain is

`ftx-docs` documents a **user-service** (`07-api/contracts/openapi/auth-service.yaml`,
`06-data/data-dictionary.md` section 2) that had no repository. ADR-012 places it in
`ftx-customers-*`: this domain owns the **administrator accounts and their sessions**.

Customers still have **no account and never log in** (`01-context/scope.md`, assumption 3). Their
contact data (name, email, phone of a reservation) belongs to the reservations domain, not here.

## What this repository is (and what it is not)

Following **Annex J** of the course norm, Futbolix has **one PostgreSQL instance**, defined in
[`ftx-infra-postgres`](https://github.com/code-corhuila/ftx-infra-postgres) with its container
and its volume. This repository:

| Does | Does not |
|---|---|
| Own the structure of the `customers` schema: tables, function, trigger, indexes, roles | Define a database container or a volume |
| Ship the migration runner (`deploy/compose.yml`) that applies its migrations to the single instance | Create login users or extensions (that is `ftx-infra-postgres`) |
| Prove in CI that the schema builds from scratch, reverts and builds again | Seed an administrator: a fixed, versioned credential is forbidden |
| | Contain application code (that is `ftx-customers-api`) |

## Structure

```
01_ddl/                     definition (DDL)
  01_schemas/  V001__create_schema_customers.sql
  03_tables/   V002__create_user_account.sql
               V003__create_refresh_token.sql
  07_functions/V004__create_function_set_updated_at.sql
  09_triggers/ V005__create_trigger_user_account_updated_at.sql
  10_indexes/  V006__create_indexes.sql
02_dml/00_inserts/          empty on purpose: no seeded administrator
03_dcl/                     access control (DCL)
  00_roles/    V007__create_roles.sql        (customers_reader, customers_writer)
  01_grants/   V008__grants.sql              (customers_writer -> customers_app)
04_tcl/                     reserved: transaction blocks, manual recoveries, release tags
05_rollbacks/               one U<n> per V<n>, same family path
deploy/compose.yml          migration runner only (customers-db-migrate)
tests/verify.sql            post-migration checks
tests/rebuild.sh            rebuild check used by the CI
flyway.toml                 Flyway configuration (own schema and control table)
.github/workflows/db-ci.yml CI on every PR to develop and qa
```

## Data model

### `customers.user_account` — administrator accounts

Source: `06-data/data-dictionary.md`, table `users`. `user` is a reserved word in PostgreSQL, so
the table is `user_account` (singular, Annex A rule 1).

| Column | Type | Rule |
|---|---|---|
| `id` | `uuid` | `pk_user_account`, `gen_random_uuid()` |
| `full_name` | `varchar(150)` | `chk_user_account_full_name_not_blank` |
| `email` | `varchar(255)` | stored lower case and trimmed (`chk_user_account_email_normalised`); unique (`idx_user_account_email`) |
| `password_hash` | `varchar(255)` | `chk_user_account_password_hash_bcrypt`: only a BCrypt hash fits, so a plain password cannot be stored |
| `phone` | `varchar(30)` | optional |
| `role` | `text` | `chk_user_account_role`: `ADMINISTRATOR` (CHECK, never ENUM) |
| `failed_login_count` | `integer` | consecutive failed logins, 0 or more; added for the lockout rule |
| `locked_until` | `timestamptz` | login refused until this instant after 5 consecutive failures; added for the lockout rule |
| `created_at` / `updated_at` | `timestamptz` | `updated_at` maintained by `trg_user_account_updated_at` |

The two lockout columns are not in the data dictionary: they implement
`00-governance/security-rules.md` (A07, "account lockout after 5 consecutive failed attempts").

### `customers.refresh_token` — administrator sessions

Rules from `00-governance/security-policy.md` ("Refresh Token") and `auth-service.yaml`.

| Column | Type | Rule |
|---|---|---|
| `id` | `uuid` | `pk_refresh_token`; first part of the token the client receives (`<id>.<secret>`) |
| `user_id` | `uuid` | `fk_refresh_token_user_account` (inside the schema; no cross-domain key) |
| `family_id` | `uuid` | shared by every token issued from one login |
| `token_hash` | `varchar(255)` | BCrypt hash of the secret part; never the token in clear |
| `expires_at` | `timestamptz` | at most 7 days after `created_at` (`chk_refresh_token_expiry`) |
| `used_at` | `timestamptz` | set when the token is exchanged: one use only |
| `revoked_at` | `timestamptz` | set on logout, or on the whole family when a spent token is presented again |
| `created_at` | `timestamptz` | |

### Access (Annex J.7)

| Role | Kind | Can |
|---|---|---|
| `customers_reader` | `NOLOGIN` | `SELECT` on both tables **except** `password_hash` and `token_hash` (column grants) |
| `customers_writer` | `NOLOGIN` | `SELECT, INSERT, UPDATE` on both tables; never `DELETE`; never DDL |
| `customers_app` | `LOGIN`, created by `ftx-infra-postgres` | receives `customers_writer`; `ftx-customers-api` connects with it |

`INSERT` on `user_account` exists only so `ftx-customers-api` can create the **first**
administrator at start-up from deployment variables. No application role can read
`flyway_schema_history`.

## How to run the migrations

From `ftx-infra-postgres`, with the repositories cloned as siblings:

```bash
docker network create platform-dev                                          # once per machine and environment
docker compose --env-file env/dev.env up -d --wait postgres                 # the single instance
docker compose --env-file env/dev.env run --rm customers-db-migrate         # apply what is pending
docker compose --env-file env/dev.env run --rm customers-db-migrate         # again: "No migration necessary"
docker compose --env-file env/dev.env run --rm customers-db-migrate info
docker compose --env-file env/dev.env run --rm customers-db-migrate validate
```

`ftx-infra-postgres` must create `customers_app` in its `postgres/init/01-instance.sh` and read
`CUSTOMERS_APP_PASSWORD` from its env files (Annex J.5.5).

### Rebuild check without Docker

`tests/rebuild.sh` runs against any **empty** PostgreSQL 16 database. It needs two commands in the
environment: `FLYWAY` (Flyway 10.22.0 pointed at the database, with `-configFiles=flyway.toml`)
and `PSQL` (psql pointed at the same database). Create `customers_app` first, as the CI does.

## Rollback

Flyway Community does not revert. Each `V<n>` has its `U<n>` in `05_rollbacks/`, applied with
`psql` from the highest number to the lowest, after deleting `customers.flyway_schema_history`
(Annex J.6). The CI does it on every Pull Request. In `qa` and `main` a mistake is fixed with a
**new** forward migration; the `U` scripts are used only in a recovery decided and recorded in
`04_tcl/`.

## Rules

- A migration that already ran in any environment is **never edited**: a fix is a new `V<n>`.
- The next migration takes the next number (`V009`), whatever its family.
- Every new `V<n>` comes with its `U<n>` and, if it adds a rule, a check in `tests/verify.sql`.
- No migration inserts an administrator or any credential.
- In `qa` and `main`, never `docker compose down -v`: the volume is the history (Annex J.5.4).

## Branching

`develop`, `qa` and `main` accept no direct commits. Changes enter `develop` from `feat/`,
`fix/` or `chore/` branches through a Pull Request; promotion to `qa` and `main` re-applies them
with `git cherry-pick -x` (`00-governance/branching-policy.md` in `ftx-docs`). `main` requires the
approval of `ariel5253`.
