# B1 Containerization: Full Session Summary

## What was done

### b1b: Docker Compose split
- Rewrote docker-compose.yml as production base (RAILS_ENV=production,
  Puma CMD, secrets via env var interpolation)
- Created docker-compose.override.yml for dev (foreman, source mounts,
  mailpit, Caddy on :8080)
- Caddyfile uses `{$CADDY_ADDRESS}` env var for port/hostname
- Dockerfile CMD changed from foreman to puma
- Asset precompilation added to Dockerfile
- Entrypoint skips dev-only steps in production
- Initially used .example pattern for override, dropped it (YAGNI)

### Hardening (from reviewer sub-agent)
- Multi-stage Dockerfile: build stage compiles, production stage is leaner
- Non-root `rails` user (uid 1000) in production; dev runs as root via override
- db:prepare split into db:create (idempotent) + db:migrate (fail hard) + db:seed (dev, non-fatal)
- Restart policies (unless-stopped) on all services
- Resource limits: db 512M, ES 1G, rails 512M, caddy 128M
- Gzip/zstd compression in Caddy
- Removed deprecated X-XSS-Protection header

### Production readiness
- Elasticsearch xpack.security enabled in production with ELASTIC_PASSWORD env var
- Dev override disables ES security
- Entrypoint uses $ELASTICSEARCH_URL for health check (supports embedded creds)
- JSON-file log rotation (10MB x 5 files) on all services
- bin/backup and bin/restore scripts for PostgreSQL
- Production ActionMailer configured with SMTP env vars (host, port, user, password, STARTTLS)

### Mailer cleanup
- ApplicationMailer from address moved to MAILER_FROM env var
- BorrowerMailer removed duplicate hardcoded from address, inherits from ApplicationMailer
- All mail-related secrets (relay, user, password, from address) are env-only

### Deployment planning
- Created docs/plans/b1c_production-deployment.md
- Manual first-time server setup: Docker install, clone, .env, build, start
- App is publicly accessible at bonanza.fh-potsdam.de (not VPN-only)
- Caddy handles Let's Encrypt automatically
- Updated EXECUTION-ORDER.md with b1c

### Bugs filed
- b38946c: Devise allows weak passwords (GitHub #52)
- ee1b1a0: Staff-created borrowers don't receive confirmation email (GitHub #54)

### Bugs closed
- b520df1: Split docker-compose (completed)
- 7bd52bf: Execute b1: Containerization (completed)

## Gotchas
- `${VAR:?}` in compose base breaks override merge (evaluated before merge)
- `chown -R /usr/local/bundle` hangs the build (thousands of gem files);
  fixed by only chowning /app, dev runs as root
- Caddy port merge is additive (dev gets 80+443+8080); harmless
- `chown -R /app` still takes ~107s due to precompiled assets

## Key decisions
- Foreman stays in production image (~1MB, dev needs it, not worth separate image)
- No .example pattern for override file (tracked directly, one dev + one agent)
- Plain env vars in compose base (no :? syntax), warnings are harmless
- SMTP relay details kept entirely in .env, nothing in committed code

## Next
- a2: Dependency updates (Ruby 3.4+ / Rails 8.x)
