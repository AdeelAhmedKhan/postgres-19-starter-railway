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
- TLS on by default: the server generates a self-signed
  certificate on first start (kept on the volume, so it survives
  restarts) and accepts encrypted connections with
  `sslmode=require`. Set `PG_SSL=off` to disable it. Plain
  connections keep working either way.
- Optional first-boot dump import: point
  `POSTGRES_INIT_DUMP_URL` at a `.sql` or `.sql.gz` dump, or
  paste one base64-encoded in `POSTGRES_INIT_DUMP_BASE64`, and
  it is applied once, on the first start against an empty data
  directory. A broken dump fails the first boot loudly instead
  of leaving a half-imported database behind.
- Scheduled backups: a small cron service runs `pg_dump` daily
  at 03:15 UTC into a Railway Bucket in the same project,
  verifies each archive is readable before uploading, and keeps
  the newest 14 dumps (`BACKUP_RETENTION_COUNT`).
- A persistent volume at `/var/lib/postgresql` (the image keeps data in its versioned subdirectory, `19/docker`)
- The official image's variable contract: `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, `POSTGRES_DB`

## Variables

| Variable | Value |
| --- | --- |
| `POSTGRES_USER` | `postgres` unless you change it |
| `POSTGRES_PASSWORD` | Generated at deploy time by the template |
| `POSTGRES_DB` | `railway` unless you change it |
| `PG_SSL` | `on` by default; `off` disables TLS |
| `POSTGRES_INIT_DUMP_URL` | Optional; empty means no import |
| `POSTGRES_INIT_DUMP_BASE64` | Optional; empty means no import |
| `BACKUP_RETENTION_COUNT` | `14` on the backup service |

Connect from another service in the same project with the
reference variable `PGURL`, or from outside through the TCP
proxy the template enables on port 5432. For an encrypted
connection add `?sslmode=require` to the connection string;
the certificate is self-signed, so `sslmode=verify-full`
cannot validate it.

Restoring a backup: download a dump from the bucket and run
`pg_restore` into the target database. The backup service's
logs list every archive it uploads.

## Honest scope

- Single node. No replication, high availability, or failover.
- Backups are scheduled `pg_dump` archives, **not**
  point-in-time recovery: a restore lands at the moment of the
  dump, not at an arbitrary moment between dumps.
- TLS uses a self-signed certificate, the same trade Railway's
  own SSL Postgres image makes. It encrypts traffic; it does
  not prove the server's identity to a verifying client.
- No major-version auto upgrade. Moving to a future major
  version is a dump and restore; the scheduled backups make
  that a routine operation rather than an emergency.
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
Live Railway verification, 2026-11-20: a fresh deploy of this
template was verified end to end and the test project deleted
afterwards. The deploy logs showed the init process completing
and "database system is ready to accept connections", and an
authenticated connection over the TCP proxy confirmed
PostgreSQL 19.0 (Debian 19.0-1.pgdg13+1), the `vector`
extension at 0.8.7 already created in the application database,
a nearest-neighbour query returning the correct ordering, and
a wrong password rejected. The first live test of the official
image build failed and is recorded honestly: the volume was
still mounted at the pre-18 path `/var/lib/postgresql/data`,
which the current official image refuses; the mount is now
`/var/lib/postgresql`, as this template ships it.
