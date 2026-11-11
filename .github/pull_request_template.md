## User story

<!-- Reference in the docs repository, for example: code-corhuila/ftx-docs#12 -->
HU: code-corhuila/ftx-docs#

## What changes and why

-

## How it was tested

- [ ] `db-ci` workflow is green (migrate, second migrate applies nothing, rollback with the U scripts, migrate again)
- [ ] `tests/verify.sql` passes

## Promotion trail (only for PRs to `qa` or `main`)

<!-- One line per re-applied commit, as written by git cherry-pick -x -->
- `<new sha>` (cherry picked from commit `<original sha>`)

## Checklist

- [ ] No secrets, no `.env`, no passwords (only `.env.example` with placeholders)
- [ ] No schema change outside this `-db` repository
- [ ] No migration that already ran was edited (changes go in a new `V<n>` file with its `U<n>`)
- [ ] Every new `V<n>` has its `U<n>` in `05_rollbacks/`
- [ ] No administrator seeded with a fixed credential (the first one is created by ftx-customers-api)
