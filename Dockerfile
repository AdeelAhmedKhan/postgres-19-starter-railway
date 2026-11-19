# syntax=docker/dockerfile:1
# PostgreSQL 19 + pgvector — our own image, built from the
# PostgreSQL project's own PGDG apt packages. No waiting on the
# official Docker Hub image, which did not exist yet when
# PostgreSQL 19 went GA on 2026-11-19.
#
# Why PGDG: it is the packaging the PostgreSQL Global Development
# Group itself publishes, and the same source the official Docker
# image is built from. Versions are pinned exactly below; a patch
# release (19.1, pgvector 0.8.8) is a deliberate bump of those
# pins, never a silent drift.
#
# Layout follows the official postgres image conventions:
# PGDATA on the volume path, POSTGRES_USER / POSTGRES_PASSWORD /
# POSTGRES_DB variables, /docker-entrypoint-initdb.d scripts.

FROM debian:trixie-slim

ENV PG_MAJOR=19 \
    PGDATA=/var/lib/postgresql/data \
    LANG=en_US.utf8 \
    PATH=/usr/lib/postgresql/19/bin:$PATH

# PGDG repository (the PostgreSQL project's own), then the pinned
# server + pgvector packages. postgresql-client-19 comes with the
# server package's dependency chain and is used by the entrypoint's
# temporary-server step.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen en_US.utf8 \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-19=19.0-1.pgdg13+1 \
        postgresql-19-pgvector=0.8.7-1.pgdg13+2 \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/*

# Fail the BUILD, not the deploy, if the pinned stack is not
# exactly what this template promises.
RUN postgres --version | grep -q 'PostgreSQL) 19.0' \
    && grep -q "default_version = '0.8.7'" /usr/share/postgresql/19/extension/vector.control

RUN mkdir -p "$PGDATA" /var/run/postgresql /docker-entrypoint-initdb.d \
    && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql /docker-entrypoint-initdb.d

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# chmod here, not just in git: push routes have dropped exec bits
# before (the mvnw lesson), and the entrypoint must be executable.
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
COPY initdb.d/10-pgvector.sql /docker-entrypoint-initdb.d/10-pgvector.sql

USER postgres
EXPOSE 5432
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
