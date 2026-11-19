#!/bin/bash
# Entrypoint for the PostgreSQL 19 + pgvector template.
# Follows the official postgres image's contract:
# - First start (empty PGDATA): initdb with POSTGRES_USER,
#   POSTGRES_PASSWORD and POSTGRES_DB, run initdb.d scripts,
#   then hand over to postgres.
# - Later starts: postgres directly on the existing data.
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-$POSTGRES_USER}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    if [ -z "${POSTGRES_PASSWORD:-}" ] && [ "${POSTGRES_HOST_AUTH_METHOD:-}" != "trust" ]; then
        echo "ERROR: POSTGRES_PASSWORD is not set and POSTGRES_HOST_AUTH_METHOD is not 'trust'." >&2
        echo "Set POSTGRES_PASSWORD (the template generates one at deploy time)." >&2
        exit 1
    fi

    INITDB_ARGS=(--username="$POSTGRES_USER" --encoding=UTF8 --locale=en_US.utf8)
    if [ "${POSTGRES_HOST_AUTH_METHOD:-}" = "trust" ]; then
        INITDB_ARGS+=(--auth=trust)
    else
        PWFILE="$(mktemp)"
        printf '%s' "$POSTGRES_PASSWORD" > "$PWFILE"
        INITDB_ARGS+=(--pwfile="$PWFILE" --auth-host=scram-sha-256 --auth-local=trust)
    fi
    initdb -D "$PGDATA" "${INITDB_ARGS[@]}"
    [ "${POSTGRES_HOST_AUTH_METHOD:-}" != "trust" ] && rm -f "$PWFILE"

    # Listen on all interfaces inside the container; Railway's
    # private network and TCP proxy are the access control.
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"

    # Temporary server on a local socket only, to create the app
    # database and run the init scripts against it.
    pg_ctl -D "$PGDATA" -o "-k /var/run/postgresql -c listen_addresses=''" -w start >/dev/null
    if [ "$POSTGRES_DB" != "postgres" ]; then
        psql -v ON_ERROR_STOP=1 --host /var/run/postgresql --username "$POSTGRES_USER" --dbname postgres \
            -c "CREATE DATABASE \"$POSTGRES_DB\";"
    fi
    for f in /docker-entrypoint-initdb.d/*.sql; do
        [ -f "$f" ] || continue
        psql -v ON_ERROR_STOP=1 --host /var/run/postgresql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
    done
    pg_ctl -D "$PGDATA" -m fast -w stop >/dev/null
    echo "PostgreSQL 19 init complete (database: $POSTGRES_DB, user: $POSTGRES_USER)."
fi

exec postgres -D "$PGDATA"
