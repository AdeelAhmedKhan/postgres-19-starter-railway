# PostgreSQL 19 + pgvector — Railway Template

PostgreSQL **19.0** with **builtin pgvector support for AI
work**: pgvector 0.8.7 is included for AI workloads, vector
search, and embeddings, and the `vector` extension is created
in your database at first start. Plain Postgres use is
completely unaffected: if you never touch the vector
extension, this is simply PostgreSQL 19 with TLS on by
default. Ready to deploy on Railway. Single node, SCRAM
authentication, persistent volume.

## Why this exists

PostgreSQL 19 went generally available on 19 November 2026, and
Railway had no standalone PostgreSQL 19 template; its own
database template still runs 18. This template shipped on day
one with its own image built from **PGDG** packages, because
Docker Hub's official `postgres` image had no 19 tags yet and
waiting would have wasted the release window. The official tags
landed on 20 November 2026 and the template moved onto the
official image the same day, keeping pgvector from PGDG. On
23 November 2026 the base moved again, to the pgvector
project's own image, which is PostgreSQL 19.0 with pgvector
built in by the team that maintains it: the more trustworthy
base for a template other people deploy, and one less install
step to go wrong. On 27 November 2026 the base moved back
to the official `postgres:19.0` image plus pgvector 0.8.7
from PGDG, on Ahmed's call: he prefers the official base
image. The template now deploys a prebuilt image,
`ghcr.io/adeelahmedkhan/postgres-19-pgvector:19.0`, built by
GitHub Actions from this repo's Dockerfile. PostgreSQL 14 reached end of life on
12 November 2026, so 19 is both the new-project default and
the upgrade target.

What is new in 19: REPACK is now a core command for online table
rebuilds, and WAIT gives read-your-writes consistency on
standbys. A few late features were reverted before release
(SQL/PGQ graph queries among them), so this template claims
nothing about those.

## What you get

- PostgreSQL 19.0 with pgvector 0.8.7, on the official
  `postgres:19.0` image (pinned by tag and digest in the
  Dockerfile) plus pgvector 0.8.7 from PGDG, the PostgreSQL
  project's own apt repository
- Deploys from a prebuilt image,
  `ghcr.io/adeelahmedkhan/postgres-19-pgvector:19.0`, built by
  GitHub Actions from this repo's Dockerfile; no build runs
  at deploy time
- pgvector 0.8.7 installed for AI work (vector search,
  embeddings), with `CREATE EXTENSION vector` already run in
  your application database. If you don't need vectors,
  ignore it: plain Postgres works exactly as usual
- SCRAM-SHA-256 password authentication; a wrong password is
  rejected, verified in testing
- TLS on by default: the server generates a self-signed
  certificate on first start (kept on the volume, so it survives
  restarts, and valid for 3,650 days, so there is no renewal
  step) and accepts encrypted connections with
  `sslmode=require`. Set `PG_SSL=off` to disable it. Plain
  connections keep working either way.
- Optional first-boot dump import: point
  `POSTGRES_INIT_DUMP_URL` at a `.sql` or `.sql.gz` dump, or
  paste one base64-encoded in `POSTGRES_INIT_DUMP_BASE64`, and
  it is applied once, on the first start against an empty data
  directory. A broken dump fails the first boot loudly instead
  of leaving a half-imported database behind.
- Optional scheduled backups: this repo includes a small
  add-on service (`services/backup/`) you can deploy
  alongside the database. It runs `pg_dump` daily at 03:15
  UTC into a Railway Bucket, verifies each archive is
  readable before uploading, and keeps the newest 14 dumps
  (`BACKUP_RETENTION_COUNT`). It is not part of the template
  deploy itself.
- A persistent volume at `/var/lib/postgresql` (the image keeps data in its versioned subdirectory, `19/docker`)
- The standard Postgres variable contract: `POSTGRES_USER`,
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
| `BACKUP_RETENTION_COUNT` | `14` on the optional backup add-on |

Connect from another service in the same project with the
reference variable `DATABASE_URL` (the same value is also
exposed as `PGURL`). From outside Railway, use
`DATABASE_PUBLIC_URL`, which routes through the TCP proxy
the template enables on port 5432. For an encrypted
connection add `?sslmode=require` to the connection string;
the certificate is self-signed, so `sslmode=verify-full`
cannot validate it. Clients set to verify-full by default
(some drivers, including Prisma without parameters and
psycopg) should use `sslmode=require`, or set `PG_SSL=off`
if TLS is not needed.

The vector extension is already created in your database,
so you can go straight to work:

```sql
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT * FROM items ORDER BY embedding <=> '[3,1,2]' LIMIT 5;
```

What runs in your project: one service, the database, with
its persistent volume. Nothing else runs unless you add it.

Restoring an add-on backup: download a dump from the bucket
and run `pg_restore` into the target database. The add-on's
logs list every archive it uploads.

## Honest scope

- Single node. No replication, high availability, or failover.
- The optional backup add-on produces scheduled `pg_dump`
  archives, **not** point-in-time recovery: a restore lands
  at the moment of the dump, not at an arbitrary moment
  between dumps.
- TLS uses a self-signed certificate, the same trade Railway's
  own SSL Postgres image makes. It encrypts traffic; it does
  not prove the server's identity to a verifying client.
- No major-version auto upgrade. Moving to a future major
  version is a dump and restore; the optional backup add-on
  makes that a routine operation rather than an emergency.
- Patch releases (19.1 and later) arrive when the version pins
  in the Dockerfile are bumped, not silently. Watch the repo.

## Verification

Base change, 2026-11-27: the image base moved back to the
official `postgres:19.0` image plus pgvector 0.8.7 from PGDG
(Ahmed's call: he prefers the official base image), and the
template now deploys the prebuilt image
`ghcr.io/adeelahmedkhan/postgres-19-pgvector:19.0`, built by
GitHub Actions from this repo's Dockerfile. This new base was
live-verified the same day: a fresh deploy of the prebuilt
image on Railway confirmed PostgreSQL 19.0, pgvector 0.8.7,
a TLS 1.3 session over `sslmode=require`, a nearest-neighbour
query returning the correct ordering, and an identical
re-probe after a service restart. The test project was
deleted afterwards. Everything below describes the previous
base.

Local parity test, 2026-11-20, on the same versions this
template ships (PostgreSQL 19.0, pgvector 0.8.7): a scratch
cluster ran PostgreSQL 19.0, `CREATE EXTENSION vector` activated
pgvector 0.8.7, a nearest-neighbour query over a `vector(3)`
column returned the correct ordering, and a wrong password over
TCP was rejected. The local test ran the Ubuntu PGDG packages;
the shipped image is a Debian (trixie) build of the same
PostgreSQL version.
Base change, 2026-11-23: the image base moved from the
official `postgres` image (with pgvector added from PGDG) to
the pgvector project's official image,
`pgvector/pgvector:0.8.7-pg19-trixie`, pinned by digest. A
fresh deploy of the template on the new base was verified
the same day: PostgreSQL 19.0 (Debian 19.0-1.pgdg13+1), the
`vector` extension at 0.8.7 already created, a
nearest-neighbour query returning the correct ordering, an
`sslmode=require` connection negotiating TLS 1.3
(`pg_stat_ssl`), a wrong password rejected, and a manual
backup run producing a verified dump in the project bucket.
The test project was deleted afterwards. Later on
2026-11-23 the backup service and bucket were removed from
the template itself and kept in this repo as an optional
add-on under `services/backup`, the same code that passed
the backup verification described below: Ahmed's call, to
match the one service shape of Railway's own Postgres
template and to remove the deploy flow's cron confirmation
stop.
Final shape verification, 2026-11-23: after the backup
components were removed, a fresh deploy of the one service
template was verified again end to end. The deploy needed
no input and no configuration clicks, and an authenticated
connection over the TCP proxy confirmed PostgreSQL 19.0,
the `vector` extension at 0.8.7, a TLS 1.3 session, and a
nearest-neighbour query returning the correct ordering.
The test project was deleted afterwards.
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
Feature verification, 2026-11-20: TLS, dump import, and
scheduled backups were each verified on live deploys of the
feature build, and the test projects were deleted afterwards.
TLS: an `sslmode=require` connection through the public proxy
negotiated TLS 1.3, plain connections were upgraded or
accepted as configured, and a wrong password was rejected.
Dump import: a deploy with `POSTGRES_INIT_DUMP_BASE64` set
created the imported table with its row present, confirmed by
querying the database, not only the logs. Backups: the cron
service produced verified dumps in the project bucket on
repeated runs, and a restore drill passed end to end: the
newest scheduled dump was downloaded and restored with
`pg_restore` into a fresh database, where the data planted
before the backup was present and the restored `vector`
extension answered a distance query. Three defects were found
by these live tests and fixed, and are recorded here so the
fixes are not lost: the import script must connect over the
local socket during init (the template's `PGHOST` points at
the private domain, which refuses connections at init time);
the generated password uses a URL-safe alphabet only, because
a `/` from the base64 alphabet corrupts the connection
strings the password is embedded in; and the bucket name
must be wired from the bucket's `BUCKET` variable, which is
the real S3 bucket name, not `RAILWAY_BUCKET_NAME`, which is
the display name and made every upload fail with
NoSuchBucket. Backups remain scheduled dumps, not
point-in-time recovery.
