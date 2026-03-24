<!-- ABOUTME: Records the fulfilled plan for aligning local Docker DB credentials with test configuration defaults. -->
<!-- ABOUTME: Documents the implemented fix, verification steps, and follow-up notes for future sessions. -->

# Fix test DB config

## Problem

Local development used mismatched PostgreSQL passwords:

- `docker/docker-compose.override.yml` used `password`
- `config/database.yml` defaults used `postgres`
- CI (`.github/workflows/test.yml`) used `postgres`

This caused local `rails test` runs to fail against the Compose database unless
agents manually started a separate test-only database container.

## Decision

Use one shared default credential across local dev, local test, and CI:
`postgres/postgres`.

## Implementation

Updated `docker/docker-compose.override.yml`:

- `services.db.environment.POSTGRES_PASSWORD`
- `services.rails.environment.DEV_DATABASE_PASSWORD`
- `services.rails.environment.TEST_DATABASE_PASSWORD`
- `services.worker.environment.DEV_DATABASE_PASSWORD`
- `services.worker.environment.TEST_DATABASE_PASSWORD`

All five values were changed from `password` to `postgres`.

## Verification

- Recreated the Compose DB with a fresh volume
- Ran test DB setup (`rails db:create db:schema:load` in test env)
- Ran full suite: `684 runs, 1343 assertions, 0 failures, 0 errors, 0 skips`

## Result

`docker compose up` and local `rails test` now work together out of the box
with default settings.

PR: https://github.com/bonanzahq/bonanza/pull/260
