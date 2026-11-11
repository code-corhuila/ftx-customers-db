#!/bin/sh
# Rebuild check of Annex A ("La verificacion de reconstruccion con Flyway") and Annex J.6.
# Used by .github/workflows/db-ci.yml; it can also run locally against an EMPTY database.
#
# Required environment:
#   FLYWAY  command that runs Flyway already pointed at the database
#           (for example: "docker run --rm --network host -v $PWD:/workspace flyway/flyway:10.22.0
#            -workingDirectory=/workspace -configFiles=flyway.toml -url=... -user=... -password=...")
#   PSQL    command that runs psql against the same database
set -eu

step() { echo; echo "==> $1"; }

step "1. migrate: the whole schema is built from an empty database"
$FLYWAY migrate

step "2. post-migration checks"
$PSQL -v ON_ERROR_STOP=1 -f tests/verify.sql

step "3. migrate again: must apply nothing"
OUT=$($FLYWAY migrate)
echo "$OUT"
echo "$OUT" | grep -q "No migration necessary" || { echo "FAIL second migrate applied changes"; exit 1; }

step "4. rollback: the U scripts, from the highest to the lowest"
$PSQL -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS customers.flyway_schema_history"
for u in $(find 05_rollbacks -name 'U*__*.sql' | awk -F/ '{print $NF" "$0}' | sort -r | cut -d' ' -f2); do
  echo "    $u"
  $PSQL -v ON_ERROR_STOP=1 -q -f "$u"
done
LEFT=$($PSQL -tA -c "SELECT count(*) FROM pg_namespace WHERE nspname = 'customers'")
ROLES=$($PSQL -tA -c "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'customers\_%' AND rolname <> 'customers_app'")
[ "$LEFT" = "0" ] && [ "$ROLES" = "0" ] || { echo "FAIL rollback left schema=$LEFT roles=$ROLES"; exit 1; }
echo "OK  the database is empty again"

step "5. migrate after the rollback: rebuilds again"
$FLYWAY migrate
$PSQL -v ON_ERROR_STOP=1 -f tests/verify.sql
echo; echo "REBUILD CHECK PASSED"
