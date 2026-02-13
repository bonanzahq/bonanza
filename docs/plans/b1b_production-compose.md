# Production Docker Compose Split

## Objective

Split `docker-compose.yml` into a production base and a development override
so the same stack can serve both environments cleanly.

## Approach

Use Docker Compose's built-in override convention:

- `docker-compose.yml` -- production config (the canonical definition)
- `docker-compose.override.yml` -- development additions (auto-merged)

Developers run `docker compose up` and get both files merged automatically.
Production deploys use `docker compose -f docker-compose.yml up` to skip
the override.

## File Structure

### docker-compose.yml (production base)

**Services:** db, elasticsearch, rails, caddy

- `RAILS_ENV=production`
- No source volume mounts (code baked into image)
- No node_modules volume
- No Mailpit
- Only Caddy port exposed to host (80/443)
- Caddy with `auto_https` enabled
- SMTP configured via env vars for real relay (FHP SMTP)
- DB password via env var (not hardcoded)
- CMD: `bundle exec puma -C config/puma.rb`
- APP_HOST/APP_PORT from env vars

**Dockerfile changes:**

- Multi-stage or conditional: production precompiles assets at build time
- No foreman in production (Puma only, no watchers)

### docker-compose.override.yml (development)

**Overrides/additions:**

- `RAILS_ENV=development`
- Source volume mount `.:/app`
- node_modules volume
- Mailpit service added
- All service ports exposed to host for debugging
- Caddy with `auto_https off`, port 8080
- SMTP pointing to mailpit:1025
- DB password hardcoded to `password`
- CMD: `foreman start -f Procfile.dev`
- APP_HOST=localhost, APP_PORT=8080

### Caddyfile

Two options:
1. Single Caddyfile with env var substitution (Caddy supports `{$ENV}`)
2. Two Caddyfiles, one per environment

Option 1 is simpler.

### .env.example

Update to document both development and production variables.

## Implementation Steps

1. Extract production concerns from current `docker-compose.yml` into the
   base file (remove dev-specific settings)
2. Move development-specific config into `docker-compose.override.yml`
3. Add `docker-compose.override.yml` to `.gitignore` (track a
   `docker-compose.override.yml.example` instead so each dev can customize)
4. Update Caddyfile for env-based HTTPS toggle
5. Update Dockerfile CMD back to Puma (foreman comes from override)
6. Update `docker-entrypoint.sh` to conditionally skip dev-only steps in
   production (like ES reindex on every boot)
7. Update README with production deployment instructions
8. Test: `docker compose up` still works for development
9. Test: `docker compose -f docker-compose.yml up` works for production

## Open Questions

- **Secrets management for production:** env vars from host? Docker secrets?
  `.env` file excluded from git? Decide during implementation.
- **Caddy domain name:** needs to be configured for production HTTPS. FHP
  will provide the domain.
- **Image registry:** production needs to pull a pre-built image, not build
  from source. Defer to CI/CD phase (b4) which sets up the build pipeline.
