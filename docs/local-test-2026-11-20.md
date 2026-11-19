# Local parity test — PostgreSQL 19 + pgvector — 2026-11-20

Route: the template's own image is built from PGDG, the
PostgreSQL project's apt repository. This test installed the
PGDG packages on this VM (Ubuntu build: postgresql-19
19.0-1.pgdg24.04+1, postgresql-19-pgvector 0.8.7-1.pgdg24.04+2)
and ran a scratch cluster from them. The image installs the
Debian trixie build of the same pinned versions
(19.0-1.pgdg13+1, 0.8.7-1.pgdg13+2, both confirmed present in
the PGDG pool on 2026-11-20). Distro differs; packaging and
versions are the same source.

## Results (all read from live command output)

- `postgres --version`: PostgreSQL 19.0 (PGDG build).
- `SELECT version()`: PostgreSQL 19.0 on x86_64-pc-linux-gnu.
- `CREATE EXTENSION vector`: success; pg_extension reports
  pgvector **0.8.7** active on PostgreSQL 19.
- Vector round-trip: table with a `vector(3)` column, three
  rows inserted, nearest-neighbour query
  `ORDER BY emb <=> '[1,0,0]'` returned ids **1, 3** in that
  order — the exact match first, then the near vector. Correct.
- Wrong password over TCP (scram-sha-256 host auth): rejected
  with "password authentication failed".
- Cluster stopped cleanly.

## Not covered by this test

- The Docker image build itself (no Docker on this VM). The
  image's first full build is the Railway live test, which runs
  right after publishing.
- Restart persistence inside the container (the entrypoint's
  existing-data path) — covered by the live test's redeploy
  check if run, otherwise untested and stated as such.
