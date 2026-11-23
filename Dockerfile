# syntax=docker/dockerfile:1
# PostgreSQL 19 + pgvector — the pgvector project's official
# image: PostgreSQL 19.0 with pgvector 0.8.7 built in by the
# team that maintains pgvector, pinned by tag and digest below.
# The template's own extras (TLS wrapper, init scripts) layer
# on top; nothing else is added to the database image.
#
# History: this template first shipped on 2026-11-20 with its
# own debian + PGDG image, because the official postgres:19
# image did not exist yet when PostgreSQL 19 went GA on
# 2026-11-19. It moved to the official postgres image the day
# the Docker Hub tags landed (2026-11-20), adding pgvector
# from PGDG. On 2026-11-23 it moved to the pgvector project's
# image (Ahmed's call): a template other people deploy should
# stand on the base its users can trust and verify, the image
# maintained by the pgvector team itself, and the swap also
# removes this template's own PGDG install step. Versions are
# pinned exactly; a patch release (19.1, pgvector 0.9.0) is a
# deliberate bump of those pins, never a silent drift.

FROM pgvector/pgvector:0.8.7-pg19-trixie@sha256:454ef8175fbb888961034dd4fa3a5334a138b277176052d32ab081ddc4d9f722

# curl, openssl and ca-certificates serve the template's own
# extras: TLS certificate generation and dump downloads.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
