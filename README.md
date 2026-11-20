# PostgreSQL 19 + pgvector — Railway Template

PostgreSQL **19.0** with **pgvector 0.8.7** preinstalled, on the
official PostgreSQL image with pgvector added from PGDG, the
PostgreSQL project's own apt repository. Ready to deploy on
Railway. Single node, SCRAM authentication, persistent volume,
and the `vector` extension created in your database at first
start.

## Why this exists

PostgreSQL 19 went generally available on 19 November 2026, and
Railway had no standalone PostgreSQL 19 template; its own
database template still runs 18. This template shipped on day
one with its own image built from **PGDG** packages, because
Docker Hub's official `postgres` image had no 19 tags yet and
waiting would have wasted the release window. The official tags
landed on 20 November 2026 and the template moved onto the
official image the same day, keeping pgvector from PGDG, which
is also the package source the official image itself is built
from. PostgreSQL 14 reached end of life on 12 November 2026, so
19 is both the new-project default and the upgrade target.

What is new in 19: REPACK is now a core command for online table
rebuilds, and WAIT gives read-your-writes consistency on
standbys. A few late features were reverted before release
(SQL/PGQ graph queries among them), so this template claims
nothing about those.

## What you get

- PostgreSQL 19.0 (official image, pinned by tag and digest in the Dockerfile; pgvector pinned to the exact PGDG package)
- pgvector 0.8.7 installed, with `CREATE EXTENSION vector`
  already run in your application database
- SCRAM-SHA-256 password authentication; a wrong password is
  rejected, verified in testing
- A persistent volume at `/var/lib/postgresql/data`
- The official image's variable contract: `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, `POSTGRES_DB`

## Variables

| Variable | Value |
| --- | --- |
| `POSTGRES_USER` | `postgres` unless you change it |
| `POSTGRES_PASSWORD` | Generated at deploy time by the template |
| `POSTGRES_DB` | `railway` unless you change it |

Connect from another service in the same project with the
reference variable `PGURL`, or from outside through the TCP
proxy the template enables on port 5432.

## Honest scope

- Single node. No replication, high availability, or failover.
- No backups. Snapshot the volume or run `pg_dump` on a schedule.
- No TLS inside the container. Prefer Railway's private network
  for service-to-service traffic.
- Patch releases (19.1 and later) arrive when the version pins
  in the Dockerfile are bumped, not silently. Watch the repo.

## Verification

Local parity test, 2026-11-20, on the exact PGDG packages this
image runs (PostgreSQL 19.0-1, pgvector 0.8.7-1): a scratch
cluster ran PostgreSQL 19.0, `CREATE EXTENSION vector` activated
pgvector 0.8.7, a nearest-neighbour query over a `vector(3)`
column returned the correct ordering, and a wrong password over
TCP was rejected. The local test ran the Ubuntu PGDG packages;
the image uses the Debian (trixie) packages from the same
repository, which is also where the official base image gets
its PostgreSQL.
Live Railway deploy status: see the template page; this README
is updated when a live deploy has been verified.
