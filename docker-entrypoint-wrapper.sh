#!/bin/bash
# Wrapper around the official PostgreSQL entrypoint.
#
# Adds the one thing the stock image does not configure: TLS.
# When the command is the database server and PG_SSL is not
# "off" (default: on), a self-signed certificate is generated on
# first start into /var/lib/postgresql/certs, which sits on the
# persistent volume next to the versioned data directory, so the
# same certificate survives restarts. The server then starts
# with ssl=on.
#
# Clients connect with sslmode=require. The certificate is
# self-signed, so sslmode=verify-full cannot validate it; that
# is the same trade Railway's own SSL Postgres image makes.
# Plain (unencrypted) connections still work, so turning this on
# breaks no existing client.
set -e

CERT_DIR="/var/lib/postgresql/certs"
CERT_FILE="${CERT_DIR}/server.crt"
KEY_FILE="${CERT_DIR}/server.key"

if [ "$1" = "postgres" ] && [ "${PG_SSL:-on}" != "off" ]; then
    if [ ! -f "${KEY_FILE}" ]; then
        mkdir -p "${CERT_DIR}"
        openssl req -new -x509 -days 3650 -nodes \
            -out "${CERT_FILE}" -keyout "${KEY_FILE}" \
            -subj "/CN=postgres-railway" >/dev/null 2>&1
        # The server reads the key as the postgres user, and the
        # key must not be readable by anyone else.
        chown postgres:postgres "${CERT_FILE}" "${KEY_FILE}"
        chmod 644 "${CERT_FILE}"
        chmod 600 "${KEY_FILE}"
        echo "pg19-template: generated a self-signed TLS certificate in ${CERT_DIR}"
    fi
    shift
    set -- postgres \
        -c ssl=on \
        -c ssl_cert_file="${CERT_FILE}" \
        -c ssl_key_file="${KEY_FILE}" \
        "$@"
    echo "pg19-template: starting PostgreSQL with TLS on (self-signed certificate)"
fi

exec docker-entrypoint.sh "$@"
