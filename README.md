# PostgreSQL 19 + pgvector — Railway Template

PostgreSQL **19.0** with **pgvector 0.8.7** preinstalled, on
the pgvector project's official image: PostgreSQL 19.0 with
pgvector built in by the team that maintains pgvector. Ready
to deploy on Railway. Single node, SCRAM authentication,
persistent volume, and the `vector` extension created in your
database at first start.

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
step to go wrong. PostgreSQL 14 reached end of life on
12 November 2026, so 19 is both the new-project default and
the upgrade target.

What is new in 19: REPACK is now a core command for online table
rebuilds, and WAIT gives read-your-writes consistency on
standbys. A few late features were reverted before release
(SQL/PGQ graph queries among them), so this template claims
nothing about those.

## What you get

- PostgreSQL 19.0 with pgvector 0.8.7, on the pgvector project's image, pinned by tag and digest in the Dockerfile
- pgvector 0.8.7 installed, with `CREATE EXTENSION vector`
  already run in your application database
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
- Scheduled backups: a small cron service runs `pg_dump` daily
  at 03:15 UTC into a Railway Bucket in the same project,
  verifies each archive is readable before uploading, and keeps
  the newest 14 dumps (`BACKUP_RETENTION_COUNT`).
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
| `BACKUP_RETENTION_COUNT` | `14` on the backup service |

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

What runs in your project: the database, a small backup
cron that runs `pg_dump` once a day (about a minute of
compute), and a Railway Bucket holding the newest 14
archives. If you only want the database, delete the
Postgres Backup service and the Backups bucket after
deploying; the database runs on its own and nothing else
changes.

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
