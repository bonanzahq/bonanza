# B1b: Docker Compose Production/Dev Split

## What was done

Split `docker-compose.yml` into production base + development override per
the plan at `docs/plans/b1b_production-compose.md`.

### docker-compose.yml (production base)
- Services: db, elasticsearch, rails, caddy
- RAILS_ENV=production, Puma CMD
- Secrets via `${VAR}` interpolation (no `:?` syntax -- breaks override merge)
- Caddy exposes 80/443, no other service ports published
- No source mounts, no mailpit, no node_modules volume

### docker-compose.override.yml (development)
- Added to .gitignore, .example tracked in repo
- Overrides: RAILS_ENV=development, foreman CMD, source mount, mailpit
- Caddy on :8080 with CADDY_ADDRESS env var
- Hardcoded dev credentials

### Caddyfile
- Single file with `{$CADDY_ADDRESS}` env var substitution
- Dev: `:8080` (plain HTTP), Prod: `example.com` (auto HTTPS)
- Simpler than two Caddyfiles or conditional auto_https toggle

### Dockerfile
- CMD changed from foreman to puma (override provides foreman for dev)
- Added `rails assets:precompile` build step with dummy SECRET_KEY_BASE

### docker-entrypoint.sh
- Dependency sync (bundle/pnpm install) skipped in production
- ES reindex skipped in production

## Technical decisions

- **No `:?` required-variable syntax in compose base.** Docker Compose
  evaluates interpolation before merging overrides, so `${VAR:?}` fails
  even when the override provides the value. Warnings are emitted but harmless.

- **Caddy port merge is additive.** Dev gets 80+443+8080 from merged configs.
  80/443 map to nothing inside the container (Caddy only listens on 8080 in dev).
  Harmless but slightly messy. Acceptable tradeoff vs. complexity.

- **Asset precompilation at build time.** Production image includes compiled
  assets. Dev override mounts source and runs watchers, so build-time assets
  are shadowed by the volume mount.

## Verified
- `docker compose up` (dev): all 5 services healthy, app responds on :8080
- `docker compose -f docker-compose.yml config` (prod): correct structure,
  no dev services, production env vars

## Next
- Close git-bug b520df1
- Move on to a2: dependency updates (Ruby 3.4+ / Rails 8.x)
