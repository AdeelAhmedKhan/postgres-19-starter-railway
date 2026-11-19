# GA-day parity test plan — PostgreSQL 19 standalone template

GA day: **19 Nov 2026**. RC2 lands 12 Nov; it is for tooling
preparation only. Never ship an RC.

## Order of work on GA day

1. **Confirm GA is real.** Check postgresql.org for the 19.0
   announcement. (Updated 2026-11-20: GA landed 19 Nov 2026.
   Docker Hub's official image is NOT part of the gate anymore;
   this template builds its own image from PGDG packages on
   Ahmed's instruction, so a missing Docker tag does not block.)
2. **Install the PGDG packages.** Add apt.postgresql.org for
   this distro and install the pinned versions the Dockerfile
   uses (postgresql-19, postgresql-19-pgvector). Confirm the
   exact versions exist in the PGDG pool before testing.
3. **Verify the PGDATA path for 19.** PG18 moved PGDATA to
   `/var/lib/postgresql/18/docker`. Read the official
   `postgres:19.0` image config (or its Dockerfile) and confirm
   the 19 path. If it is not `/var/lib/postgresql/19/docker`,
   update the volume mount in `railway-template.json`,
   `docker-compose.yml` and the README together.
4. **Confirm the exact patch.** `SELECT version()` in the test
   must read 19.0. If GA ships a different first patch, move the
   pin in every file together.
5. **Run the parity test.** `bash scripts/local-test.sh`, read
   the full output yourself. It checks: authenticated connection,
   version 19.0, table round-trip, wrong password rejection,
   restart persistence, and that `CREATE EXTENSION vector` fails
   on the plain template (no pgvector installed — that is the
   bundle's job, not this template's).
6. **Write the evidence report** `docs/local-test-2026-11-19.md`
   after the test passes, and update the README honest scope
   section with the verified date.
7. **Secret scan** the whole folder (no real passwords, keys or
   tokens, including tests and example files).
8. **Push to GitHub** (repo `postgres-19-starter-railway`,
   created 2026-11-11) and **publish on Railway**. GA day publish
   is AUTHORIZED (Ahmed, 2026-11-05), no separate publish approval
   for this standalone template. Verify the public page yourself:
   name, description, category Storage, one service, image
   postgres:19.0, volume path, public networking off.
9. **Update MEMORY.md and the watchlist** with the publish result.

## What blocks publish

- A failed parity test holds the publish even on GA day.
- A missing or unverified PGDATA path blocks publish.
- An RC binary blocks publish.
- A live Railway deploy stays untested until a paid plan is
  active; that is stated on the page, not hidden.

## After GA day

- Watch the official Railway template: the moment it bumps to 19,
  the timing window closes and this template competes on quality
  alone. Keep the pin current (19.1, 19.2) with a retest each time.
- The PG19 + pgvector bundle ships only when pgvector 0.9.0
  lands (still unreleased as of 2026-11-11; 0.8.7 latest).
