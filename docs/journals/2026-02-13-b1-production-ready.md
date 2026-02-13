# B1 Containerization: Production Ready

## What was done

### b1b: Docker Compose split (production base + dev override)
- Rewrote `docker-compose.yml` as production base: RAILS_ENV=production,
  Puma CMD, secrets via `${VAR}` interpolation, Caddy on 80/443
- Created `docker-compose.override.yml` for dev: RAILS_ENV=development,
  foreman CMD, source mounts, mailpit, Caddy on :8080
- Updated Caddyfile to use `{$CADDY_ADDRESS}` env var (`:8080` for dev,
  `hostname.com` for production auto-HTTPS)
- Changed Dockerfile CMD from foreman to puma (override provides foreman)
- Added asset precompilation step to Dockerfile
- Updated entrypoint to skip dev-only steps (dependency sync, ES reindex)
  in production
- Initially gitignored override with .example pattern, then dropped the
  .example dance and tracked the override directly (YAGNI)

### Reviewer findings and hardening
Ran the reviewer sub-agent against all Docker files. Tackled these:

1. **Multi-stage Dockerfile** -- Build stage compiles assets with
   build-essential + Node.js. Production stage drops build-essential,
   adds non-root `rails` user. Node.js kept in final image because dev
   override needs it for watchers.
2. **Non-root user** -- `rails` user (uid 1000) owns /app. Dev override
   sets `user: root` so bundle/pnpm install work.
3. **db:prepare error swallowing fixed** -- Split into `db:create`
   (idempotent) + `db:migrate` (fail hard) + `db:seed` (dev only, non-fatal).
4. **Restart policies** -- `restart: unless-stopped` on all services.
5. **Resource limits** -- db 512M, ES 1G, rails 512M, caddy 128M.
6. **Gzip/zstd compression** in Caddy.
7. **Removed deprecated X-XSS-Protection header**.

### Production readiness
8. **Elasticsearch security** -- xpack.security enabled in production with
   `ELASTIC_PASSWORD` env var. Dev override disables it. Entrypoint uses
   `$ELASTICSEARCH_URL` for health check (supports embedded credentials).
9. **Log rotation** -- json-file driver with 10MB x 5 files on all services.
10. **Backup/restore scripts** -- `bin/backup` (pg_dump, gzipped, 30-day
    retention) and `bin/restore` (confirmation prompt, gunzip + psql).
11. **Updated .env.example** with all production env vars.

### Bugs filed
- `b38946c` -- Devise allows weak passwords (synced to GitHub #52)
- `ee1b1a0` -- Staff-created borrowers don't receive confirmation email
  (synced to GitHub #54)

### Bugs closed
- `b520df1` -- Split docker-compose (completed)
- `7bd52bf` -- Execute b1: Containerization (completed)

## Gotchas encountered
- `${VAR:?}` required-variable syntax in compose base breaks override merge.
  Docker Compose evaluates interpolation before merging, so the base file
  fails even when the override provides the value. Use plain `${VAR}`.
- `chown -R rails:rails /usr/local/bundle` hangs the build -- thousands of
  gem files. Fixed by only chowning /app and running dev as root via override.
- Caddy port merge is additive (dev gets 80+443+8080). Harmless since Caddy
  only listens on 8080 in dev.
- `db:create` + `db:migrate` on fresh volume regenerated schema.rb with
  version 0 -- migrations weren't running properly. Discarded the schema
  change; this needs investigation if it recurs.

## Decision: foreman in production image
Planner identified that removing foreman from the production image isn't
worth the complexity. It's ~1MB and dev needs it since both environments
share the same image. Skipped.

## Next session
- a2: Dependency updates (Ruby 3.4+ / Rails 8.x)
