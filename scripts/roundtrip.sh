#!/usr/bin/env bash
# psql client round-trip for the PostgreSQL 19 template.
# Reads credentials from the environment only; it has no default password.
# Usage: PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=... ./roundtrip.sh
set -euo pipefail
: "${PGHOST:?PGHOST is required}"
: "${PGPORT:?PGPORT is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "${PGDATABASE:-postgres}" -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE IF NOT EXISTS parity (id int PRIMARY KEY, label text);" \
  -c "INSERT INTO parity VALUES (1, 'parity-ok') ON CONFLICT (id) DO UPDATE SET label = 'parity-ok';" \
  -tAc "SELECT label FROM parity WHERE id = 1;"
