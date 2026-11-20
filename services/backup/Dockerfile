# syntax=docker/dockerfile:1
# Scheduled pg_dump backups for the PostgreSQL 19 + pgvector
# template. Same pinned base as the database service, so pg_dump
# is always the same major version as the server it dumps. The
# AWS CLI uploads each dump to the template's Railway Bucket,
# which is S3-compatible storage inside the project.
FROM postgres:19.0@sha256:d2c8a7d3d224a9c0335bf9f69ae6ad0b9aa7d88c4b64bab89f0f261332f6d4de

RUN apt-get update \
    && apt-get install -y --no-install-recommends awscli \
    && rm -rf /var/lib/apt/lists/*

# Fail the BUILD, not the run, if the tools are not the promised
# versions.
RUN pg_dump --version | grep -q '19.0' \
    && aws --version

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

# Railway runs this service on its cron schedule; the command
# performs one backup and exits.
CMD ["/usr/local/bin/backup.sh"]
