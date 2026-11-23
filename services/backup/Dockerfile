# syntax=docker/dockerfile:1
# Scheduled pg_dump backups for the PostgreSQL 19 + pgvector
# template. Same pinned base as the database service, so pg_dump
# is always the same major version as the server it dumps. The
# AWS CLI uploads each dump to the template's Railway Bucket,
# which is S3-compatible storage inside the project.
FROM pgvector/pgvector:0.8.7-pg19-trixie@sha256:454ef8175fbb888961034dd4fa3a5334a138b277176052d32ab081ddc4d9f722

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
