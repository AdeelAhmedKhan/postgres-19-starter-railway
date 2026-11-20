#!/bin/bash
# Optional first-boot dump import.
#
# Runs once, only on the first start against an empty data
# directory (the official entrypoint's initdb.d contract), after
# 10-pgvector.sql has created the vector extension. Set one of:
#
#   POSTGRES_INIT_DUMP_URL     https URL of a .sql or .sql.gz dump
#   POSTGRES_INIT_DUMP_BASE64  the same dump, base64-encoded
#
# The dump is applied with ON_ERROR_STOP, so a broken dump fails
# the first boot loudly instead of leaving a half-imported
# database behind. Import only dumps from sources you trust:
# they run with full database privileges during bootstrap.
set -e

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
DUMP_FILE="${WORK}/dump.sql"

if [ -n "${POSTGRES_INIT_DUMP_URL:-}" ]; then
    echo "pg19-template: downloading database dump from POSTGRES_INIT_DUMP_URL"
    case "${POSTGRES_INIT_DUMP_URL}" in
        *.gz)
            curl -fsSL "${POSTGRES_INIT_DUMP_URL}" | gunzip -c > "${DUMP_FILE}"
            ;;
        *)
            curl -fsSL "${POSTGRES_INIT_DUMP_URL}" -o "${DUMP_FILE}"
            ;;
    esac
elif [ -n "${POSTGRES_INIT_DUMP_BASE64:-}" ]; then
    echo "pg19-template: decoding database dump from POSTGRES_INIT_DUMP_BASE64"
    printf '%s' "${POSTGRES_INIT_DUMP_BASE64}" | base64 -d > "${WORK}/dump.bin"
    if [ "$(head -c 2 "${WORK}/dump.bin" | od -An -tx1 | tr -d ' \n')" = "1f8b" ]; then
        gunzip -c "${WORK}/dump.bin" > "${DUMP_FILE}"
    else
        mv "${WORK}/dump.bin" "${DUMP_FILE}"
    fi
else
    exit 0
fi

echo "pg19-template: importing dump into database ${POSTGRES_DB}"
# Connect through the local unix socket, explicitly. The
# template sets PGHOST to the service's private domain as a
# convenience for other services, and that variable is also
# present in this container's environment; during init the
# temporary server listens only on the local socket, so a TCP
# connection to the private domain is refused (proven by the
# first live feature test, 2026-11-20).
PGHOST=/var/run/postgresql psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" -f "${DUMP_FILE}"
echo "pg19-template: dump import complete"
