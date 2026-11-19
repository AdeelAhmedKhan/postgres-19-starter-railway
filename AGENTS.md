# AGENTS.md — working in this repo

Read this before changing anything. This is a bare database template,
not an app. Keep it minimal, pinned, and honest.

## The gap this template is for

PostgreSQL 19 GA lands **19 Nov 2026** (RC2 12 Nov). As of 2026-11-11
there is **no dedicated PG19 template on the Railway marketplace**,
and Railway's own PostgreSQL template still pins postgres-ssl:18.
PostgreSQL 14 hits end of life on 12 Nov 2026, the same week, which
forces an upgrade wave. The edge is the timing window: be the first
well made standalone PG19 template on GA day, before the official
template bumps to 19 and before other community authors publish
theirs. The window is real but its length is unknown, so speed on
GA day matters, and quality is what converts the visitors who arrive
by exact version search.

This is a gap play, not a head on fight with the official template.
The official template has 391K projects and offers HA, backups and
security patches. This template wins only while it is the only
standalone PG19 on the marketplace.

## Stack (pinned — do not bump majors casually)

- PostgreSQL **19.0** + **pgvector 0.8.7**, in our own image:
  `debian:trixie-slim` plus the pinned PGDG apt packages
  (`postgresql-19=19.0-1.pgdg13+1`,
  `postgresql-19-pgvector=0.8.7-1.pgdg13+2`). PGDG is the
  PostgreSQL project's own packaging and the same source the
  official Docker image is built from.
- Why not the official `postgres:19.0` image: it did not exist
  when PG19 went GA on 19 Nov 2026 (Docker Hub tags `19` and
  `19.0` still 404 on 2026-11-20). Ahmed's standing instruction
  for release-gap templates (2026-11-20): build our own image,
  never wait for official images while a version is already
  released. The release window is the whole value of the gap play.
- When the official image eventually lands, this template does
  NOT automatically move to it: the PGDG build is equivalent in
  provenance and already published. Revisit only if the official
  image gains something this build lacks.
- No app code, no driver, no framework lives here. The only code
  is the entrypoint, one init SQL file, and the local parity
  test in `scripts/`.
- Volume: `/var/lib/postgresql/data` (this image sets PGDATA
  there itself; the path is ours, not inherited from the
  official image's layout).

## The one rule that matters

**Never fake a capability.** A health check that cannot reach the
database is a failure, even if the process is running. A test that
did not run is "not tested", not a pass. A live Railway deploy that
has not happened is "untested", not "proven". Say exactly which of
these is true in the README and in every test report.

**Never ship a release candidate.** Build at GA, not RC. RC2 lands
12 Nov; it is for tooling preparation only.

## Layout

- `README.md` — template description, exact Composer settings,
  variables, connection string, honest scope.
- `railway-template.json` — transcription of the exact Template
  Composer settings for publishing. Railway does NOT read this file
  automatically; it exists so the published template can be reviewed
  and reproduced exactly.
- `docker-compose.yml` — local equivalent of the Composer settings
  (same image, volume path, variable names). Requires Docker; the
  parity test script does not.
- `.env.example` — variable names only, placeholders only. Never put
  a real password here, in tests, or in example files.
- `scripts/local-test.sh` — installs the pinned PGDG packages
  (PostgreSQL 19 + pgvector) if missing, starts a scratch
  cluster on /tmp, sets a runtime generated password, runs the
  round-trip plus a pgvector nearest-neighbour check, checks
  wrong password rejection and restart persistence, stops the
  server, writes JSON evidence to `docs/`.
- `scripts/roundtrip.sh` — psql client round-trip. Reads credentials
  from the environment only; it has no default password.
- `docs/parity-test-plan.md` — the GA day checklist, in order.
- `docs/local-test-2026-11-19.md` — the parity test report, written
  after the test passes on GA day.

## Publishing gate (from the railway_template_publishing skill)

1. Local parity test passes, with full command responses read.
2. Secret scan of the whole folder passes (no real passwords, keys,
   or tokens, including tests and example files).
3. Publish only then, and list what is still untested (live Railway
   deploy, until a paid plan is active) on the template page and in
   the README.
4. Never report a pass you did not see, and re-run the test yourself
   after any builder finishes before reporting it.
5. GA day publish is AUTHORIZED (Ahmed, 2026-11-05): build + publish
   straight away, no separate publish approval for this standalone
   template. A failed parity test still holds the publish even on
   GA day — a broken template hurts reputation more than a late one.
6. PG19 and pgvector ship as ONE template. The earlier plan to
   wait for pgvector 0.9.0 was superseded on 2026-11-20: PGDG
   already builds pgvector 0.8.7 for PostgreSQL 19 (verified in
   the pool and in the local parity test), and Ahmed instructed
   not to wait. When pgvector 0.9.0 lands, bump the pin.
