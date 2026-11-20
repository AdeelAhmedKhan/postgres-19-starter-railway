# syntax=docker/dockerfile:1
# PostgreSQL 19 + pgvector — the official PostgreSQL 19 image
# with pgvector added from PGDG, the PostgreSQL project's own
# apt repository (already configured inside the official image,
# scoped to PostgreSQL 19). Versions are pinned exactly below; a
# patch release (19.1, pgvector 0.8.8) is a deliberate bump of
# those pins, never a silent drift.
#
# History: this template first shipped on 2026-11-20 with its own
# debian + PGDG image, because the official postgres:19 image did
# not exist yet when PostgreSQL 19 went GA on 2026-11-19. It
# moved to the official image the day the Docker Hub tags landed
# (2026-11-20), keeping the same pgvector pin. Same PGDG packages
# underneath either way; the official base is the better
# maintained and more recognisable starting point.

FROM postgres:19.0@sha256:d2c8a7d3d224a9c0335bf9f69ae6ad0b9aa7d88c4b64bab89f0f261332f6d4de

# pgvector from PGDG, pinned exactly. The official image already
# trusts the PGDG repository; no key or source setup is needed.
# curl, openssl and ca-certificates serve the template's own
# extras: TLS certificate generation and dump downloads.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-19-pgvector=0.8.7-1.pgdg13+2 \
        curl openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Fail the BUILD, not the deploy, if the stack is not exactly
# what this template promises.
RUN postgres --version | grep -q 'PostgreSQL) 19.0' \
    && grep -q "default_version = '0.8.7'" /usr/share/postgresql/19/extension/vector.control \
    && curl --version > /dev/null \
    && openssl version > /dev/null

# The official entrypoint runs everything in
# /docker-entrypoint-initdb.d once, at first start on an empty
# data directory. 10-pgvector.sql creates the vector extension in
# the application database (POSTGRES_DB); 20-import-dump.sh
# applies an optional user-supplied dump (see its header).
COPY initdb.d/10-pgvector.sql /docker-entrypoint-initdb.d/10-pgvector.sql
COPY initdb.d/20-import-dump.sh /docker-entrypoint-initdb.d/20-import-dump.sh

# The wrapper adds TLS (self-signed certificate, PG_SSL=off
# disables it) and then hands over to the official entrypoint.
# The chmod guards against push routes that drop executable
# bits: a non-executable init script is silently sourced instead
# of run, and a non-executable entrypoint does not start at all.
COPY docker-entrypoint-wrapper.sh /usr/local/bin/docker-entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh \
        /docker-entrypoint-initdb.d/20-import-dump.sh

ENTRYPOINT ["docker-entrypoint-wrapper.sh"]
CMD ["postgres"]
