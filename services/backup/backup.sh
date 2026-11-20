#!/bin/bash
# One backup run for the PostgreSQL 19 + pgvector template:
# pg_dump the application database in custom format, verify the
# archive is readable, upload it to the Railway Bucket, then
# prune old backups beyond the retention count.
#
# Exits non-zero on any failure, so a broken backup is loud in
# the service logs instead of silently missing when needed.
#
# These are scheduled logical backups, NOT point-in-time
# recovery: a restore lands at the moment of the dump.
set -euo pipefail

# Railway Bucket credentials arrive as BUCKET_* variables; the
# S3_* spellings are accepted as a fallback.
BUCKET_NAME="${BUCKET_NAME:-${S3_BUCKET:-}}"
BUCKET_ENDPOINT="${BUCKET_ENDPOINT:-${S3_ENDPOINT:-}}"
BUCKET_ACCESS_KEY_ID="${BUCKET_ACCESS_KEY_ID:-${AWS_ACCESS_KEY_ID:-}}"
BUCKET_SECRET_ACCESS_KEY="${BUCKET_SECRET_ACCESS_KEY:-${AWS_SECRET_ACCESS_KEY:-}}"

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BUCKET_NAME:?BUCKET_NAME is required}"
: "${BUCKET_ENDPOINT:?BUCKET_ENDPOINT is required}"
: "${BUCKET_ACCESS_KEY_ID:?BUCKET_ACCESS_KEY_ID is required}"
: "${BUCKET_SECRET_ACCESS_KEY:?BUCKET_SECRET_ACCESS_KEY is required}"

RETENTION="${BACKUP_RETENTION_COUNT:-14}"
PREFIX="pgdumps"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
KEY="${PREFIX}/postgres-${STAMP}.dump"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

export AWS_ACCESS_KEY_ID="${BUCKET_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${BUCKET_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${BUCKET_REGION:-us-east-1}"

# Print only the host part of the URL, never the credentials.
echo "pg19-backup: dumping ${DATABASE_URL##*@} to ${KEY}"
pg_dump --format=custom --file="${WORK}/backup.dump" "${DATABASE_URL}"

# A dump that cannot be listed cannot be restored. Verify the
# archive before uploading it, not after someone needs it.
pg_restore --list "${WORK}/backup.dump" > /dev/null
SIZE="$(stat -c %s "${WORK}/backup.dump")"
echo "pg19-backup: dump verified readable, ${SIZE} bytes"

# Upload without --quiet and capture the output: when this step
# failed silently in the first live tests, the S3 error was
# swallowed and the run was undiagnosable from the logs. On
# failure, print the full aws output so the error is in the logs.
echo "pg19-backup: uploading to bucket ${BUCKET_NAME} via ${BUCKET_ENDPOINT}"
if ! aws s3 cp "${WORK}/backup.dump" "s3://${BUCKET_NAME}/${KEY}" \
    --endpoint-url "${BUCKET_ENDPOINT}" > "${WORK}/upload.log" 2>&1; then
    echo "pg19-backup: UPLOAD FAILED, aws output follows" >&2
    cat "${WORK}/upload.log" >&2
    exit 1
fi
cat "${WORK}/upload.log"
echo "pg19-backup: uploaded s3://${BUCKET_NAME}/${KEY}"

# Retention: keys are timestamped, so sorting by name sorts by
# time. Keep the newest ${RETENTION}, delete the rest.
aws s3 ls "s3://${BUCKET_NAME}/${PREFIX}/" --endpoint-url "${BUCKET_ENDPOINT}" \
    2> "${WORK}/ls.err" | awk '{print $4}' | sort > "${WORK}/keys.txt" || true
if [ -s "${WORK}/ls.err" ]; then
    echo "pg19-backup: WARNING, listing existing backups reported errors:" >&2
    cat "${WORK}/ls.err" >&2
fi
TOTAL="$(grep -c . "${WORK}/keys.txt" || true)"
if [ "${TOTAL}" -gt "${RETENTION}" ]; then
    REMOVE=$((TOTAL - RETENTION))
    head -n "${REMOVE}" "${WORK}/keys.txt" | while read -r OLD; do
        echo "pg19-backup: pruning old backup ${OLD}"
        aws s3 rm "s3://${BUCKET_NAME}/${PREFIX}/${OLD}" \
            --endpoint-url "${BUCKET_ENDPOINT}"
    done
fi
echo "pg19-backup: done, ${TOTAL} backup(s) in the bucket, keeping the newest ${RETENTION}"
