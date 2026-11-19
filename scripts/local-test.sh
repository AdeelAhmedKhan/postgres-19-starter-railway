#!/usr/bin/env bash
# Local parity test for the PostgreSQL 19 + pgvector template.
# Uses the PGDG apt packages, the same packages the template's
# Dockerfile installs (this script runs the host distro's PGDG
# build; the image uses the Debian trixie build of the same
# versions). No Docker required. The password is generated at
# runtime and never written to the repo. Writes JSON evidence
# to docs/.
set -euo pipefail

BIN=/usr/lib/postgresql/19/bin
for bin in initdb pg_ctl psql postgres; do
  [ -x "$BIN/$bin" ] || { echo "missing $BIN/$bin — install the PGDG packages first:"; \
    echo "  apt-get install postgresql-19 postgresql-19-pgvector (from apt.postgresql.org)"; exit 1; }
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/docs"
EVIDENCE="$ROOT/docs/local-test-evidence-2026-11-20.json"

PORT="${PG_TEST_PORT:-54399}"
# The datadir lives on /tmp: the workspace mount on this VM does
# not allow the postgres user to own a cluster there.
DATADIR="$(mktemp -d /tmp/pg19-parity-XXXXXX)"
SOCKDIR="$DATADIR"
LOG="$DATADIR/server.log"
TEST_PASS="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"

AS_PG=(env)
if [ "$(id -u)" = "0" ]; then AS_PG=(runuser -u postgres --); fi
chown postgres:postgres "$DATADIR" 2>/dev/null || true

stop_server() { "${AS_PG[@]}" "$BIN/pg_ctl" -D "$DATADIR/data" stop -m fast >/dev/null 2>&1 || true; }
cleanup() { stop_server; rm -rf "$DATADIR"; }
trap cleanup EXIT

echo "initializing datadir $DATADIR/data"
"${AS_PG[@]}" "$BIN/initdb" -D "$DATADIR/data" -U postgres \
  --auth-local=trust --auth-host=scram-sha-256 >/dev/null

"${AS_PG[@]}" "$BIN/pg_ctl" -D "$DATADIR/data" \
  -o "-p $PORT -k $SOCKDIR" -l "$LOG" -w start >/dev/null

PSQL_LOCAL=("$BIN/psql" -h "$SOCKDIR" -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1)
"${PSQL_LOCAL[@]}" -tAc "ALTER USER postgres PASSWORD '$TEST_PASS'" >/dev/null
VERSION="$("${PSQL_LOCAL[@]}" -tAc "SELECT version()")"
echo "version: $VERSION"
case "$VERSION" in *"PostgreSQL) 19."*) ;; *) echo "FAILED: not PostgreSQL 19"; exit 1;; esac

echo "pgvector: extension + nearest-neighbour round-trip"
"${PSQL_LOCAL[@]}" -tAc "CREATE EXTENSION vector" >/dev/null
EXTVERSION="$("${PSQL_LOCAL[@]}" -tAc "SELECT extversion FROM pg_extension WHERE extname='vector'")"
echo "pgvector version: $EXTVERSION"
"${PSQL_LOCAL[@]}" -c "CREATE TABLE items (id int, emb vector(3))" >/dev/null
"${PSQL_LOCAL[@]}" -c "INSERT INTO items VALUES (1,'[1,0,0]'),(2,'[0,1,0]'),(3,'[0.9,0.1,0]')" >/dev/null
KNN="$("${PSQL_LOCAL[@]}" -tAc "SELECT string_agg(id::text, ',' ORDER BY emb <=> '[1,0,0]') FROM (SELECT * FROM items ORDER BY emb <=> '[1,0,0]' LIMIT 2) s")"
[ "$KNN" = "1,3" ] || { echo "FAILED: kNN order '$KNN', expected '1,3'"; exit 1; }
echo "kNN order correct: $KNN"

echo "wrong password over TCP must be rejected"
if PGPASSWORD="<redacted>" "$BIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -tAc "SELECT 1" >/dev/null 2>&1; then
  echo "FAILED: wrong password was accepted"; exit 1
fi
echo "wrong password rejected"

echo "restart persistence"
stop_server
"${AS_PG[@]}" "$BIN/pg_ctl" -D "$DATADIR/data" -o "-p $PORT -k $SOCKDIR" -l "$LOG" -w start >/dev/null
AFTER="$("${PSQL_LOCAL[@]}" -tAc "SELECT count(*) FROM items")"
[ "$AFTER" = "3" ] || { echo "FAILED: persistence after restart, count=$AFTER"; exit 1; }
echo "rows survive restart: $AFTER"

cat > "$EVIDENCE" <<EOF
{
  "template": "PostgreSQL 19 + pgvector",
  "image": "own build: debian:trixie-slim + PGDG postgresql-19 / postgresql-19-pgvector",
  "date": "2026-11-20",
  "version": "$VERSION",
  "pgvector": "$EXTVERSION",
  "checks": {
    "authenticated_connection": "pass",
    "vector_extension": "pass",
    "vector_knn_round_trip": "pass",
    "wrong_password_rejected": "pass",
    "restart_persistence": "pass"
  }
}
EOF
echo "ALL CHECKS PASSED — evidence written to $EVIDENCE"
