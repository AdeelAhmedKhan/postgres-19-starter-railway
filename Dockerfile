# syntax=docker/dockerfile:1
# PostgreSQL 19 + pgvector — the official PostgreSQL 19 image
# plus pgvector from PGDG.
#
# Base: postgres:19.0, the official Docker Hub image, pinned
# by tag and amd64 digest below. pgvector 0.8.7 comes from
# PGDG (the PostgreSQL project's own apt repository, already
# configured inside the official image, so no key or source
# setup is needed), pinned exactly as
# postgresql-19-pgvector=0.8.7-2.pgdg13+1 — the trixie-pgdg
# apt candidate, verified in the PGDG pool on 2026-11-27.
# Versions are pinned exactly; a patch release (19.1,
# pgvector 0.9.0) is a deliberate bump of those pins, never
# a silent drift.
#
# History: this template first shipped on 2026-11-20 with its
# own debian + PGDG image, because the official postgres:19
# image did not exist yet when PostgreSQL 19 went GA on
# 2026-11-19. It moved to the official postgres image the day
# the Docker Hub tags landed (2026-11-20), adding pgvector
# from PGDG. On 2026-11-23 it moved to the pgvector project's
# image (Ahmed's call): the more trustworthy base for a
# template other people deploy, and one less install step.
# On 2026-11-27 it moved back to the official image plus
# pgvector from PGDG (Ahmed's call, reversing 2026-11-23):
# he prefers the official base image. The PostgreSQL and
# pgvector packages underneath are the same PGDG builds
# either way, and the entrypoint lineage is unchanged, so the
# init and volume contracts are the same throughout.
#
# This Dockerfile is the build source for the prebuilt image
# ghcr.io/ninja-templates/postgres-19-pgvector:19.0, built by
# GitHub Actions; the Railway template references that image,
# not a repo build. Bump rule: when pgvector 0.9.0 lands,
# bump the pgvector pin below, rebuild the image, retest
# live, then update the template's image digest.

FROM postgres:19.0@sha256:3fb624f672a1cb628d0bdc0f533cffad31345421eedf16ab1f85ed1ea0d07d2e

# pgvector from PGDG, pinned exactly. The official image
# already trusts the PGDG repository; no key or source setup
# is needed. curl, openssl and ca-certificates serve the
# template's own extras: TLS certificate generation and dump
# downloads.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-19-pgvector=0.8.7-2.pgdg13+1 \
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
