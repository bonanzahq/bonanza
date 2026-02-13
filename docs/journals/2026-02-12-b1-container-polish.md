# B1 Container Polish Session

## What was done

Reviewed the containerization work from previous sessions, then polished
the Docker development environment based on Fabian's feedback.

### ActionMailer + Mailpit
- Configured `delivery_method: :smtp` in development.rb with `SMTP_HOST`/`SMTP_PORT` env vars
- Set `raise_delivery_errors: true` so failures surface
- Added SMTP env vars to docker-compose.yml pointing to mailpit:1025
- Fixed `default_url_options` -- was hardcoded to localhost:3000, now
  configurable via `APP_HOST`/`APP_PORT` (set to localhost:8080 for Caddy)
- Verified: generic mail and BorrowerMailer both deliver to Mailpit

### Docker image decisions (Fabian's review)
- Node 20 -> 24 (matches mise.toml, no reason to lag behind)
- Alpine images replaced with Debian (consistent with Ruby base, easier debugging)
- PostgreSQL 15 -> 17.7 (pg gem 1.4.6 supports up to PG 17)
- All images pinned to precise versions (PG 17.7, Caddy 2.10.2, Mailpit v1.29.0, ES 8.4.0)
- Volumes prefixed with `bonanza_` to avoid collisions
- Gotcha: PG 17 can't read PG 15 data files. Volume must be wiped on major version bump.

### Hot-reload
- Added foreman to run Puma + esbuild watcher + sass watcher via Procfile.dev
- esbuild 0.14.5 didn't support `--watch=forever` (exits immediately without TTY)
- Upgraded esbuild to 0.27.3 which supports `--watch=forever`
- Added explicit `watch` and `watch:css` scripts to package.json
- Updated Procfile.dev to use these instead of appending `--watch` to build scripts
- Fixed Puma binding: `bin/rails server` defaults to 127.0.0.1, needed `-b 0.0.0.0`

### Dependency sync
- Added `bundle install` and `pnpm install --frozen-lockfile` to entrypoint
- Eliminates stale node_modules volume problem (no manual volume clearing)
- Bundle no-ops instantly, pnpm ~500ms when nothing changed
- pnpm needed `confirm-modules-purge=false` in .npmrc for non-TTY environments
  (initially used `CI=true` hack, replaced with proper config)

## Bugs filed
- `b1e9df2` -- BorrowersController calls nonexistent LenderMailer
- `476b3b2` -- CheckoutController calls nonexistent LendingMailer.confirmation_email
- `b520df1` -- Split docker-compose into production base + dev override

## Bugs closed
- `cc7f2a6` + `1464260` -- ActionMailer not configured (fixed)

## Key insight: mise.toml vs Docker
mise.toml serves local dev, Dockerfile uses nodesource + corepack. Two
sources of version truth. Acceptable for now but should match. If Docker
becomes the only dev environment, mise.toml is dead weight.

## Next session
- Execute b1b: Split docker-compose into production base + dev override
  (plan at docs/plans/b1b_production-compose.md, git-bug b520df1)
- Then a2: Dependency updates (Ruby 3.4+ / Rails 8.x)
