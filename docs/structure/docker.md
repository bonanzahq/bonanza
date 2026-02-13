# Docker Infrastructure

## File Layout

| File | Purpose |
|------|---------|
| `Dockerfile` | Builds the Rails image (gems, node packages, asset precompilation) |
| `docker-compose.yml` | Production base: db, elasticsearch, rails, caddy |
| `docker-compose.override.yml` | Development additions (gitignored, `.example` tracked) |
| `docker-compose.override.yml.example` | Template for dev override |
| `docker-entrypoint.sh` | Startup script: waits for deps, prepares DB, execs CMD |
| `Caddyfile` | Reverse proxy config with env var substitution |
| `Procfile.dev` | Foreman process file: puma + esbuild + sass watchers |
| `.env.example` | Documents required env vars for both environments |

## Two-Environment Design

### Development (`docker compose up`)

Docker Compose auto-merges `docker-compose.yml` + `docker-compose.override.yml`.

- `RAILS_ENV=development`
- Source mounted at `/app` for live reload
- Foreman runs puma + asset watchers via `Procfile.dev`
- Mailpit captures email on port 8025
- Caddy on `:8080`, plain HTTP
- All service ports exposed for debugging
- Entrypoint syncs dependencies and reindexes Elasticsearch

### Production (`docker compose -f docker-compose.yml up`)

Only the base file, no override.

- `RAILS_ENV=production`
- Code baked into image (no source mount)
- Puma runs directly (no foreman, no watchers)
- Assets precompiled at image build time
- No mailpit (SMTP configured for real relay)
- Caddy with hostname enables automatic HTTPS
- Only Caddy ports (80/443) exposed
- Entrypoint skips dependency sync and reindex

## Environment Variables

Production requires these env vars (via `.env` file or host environment):

- `POSTGRES_PASSWORD` -- database password
- `APP_HOST` -- domain name (also used as Caddy address for HTTPS)
- `SMTP_HOST`, `SMTP_PORT` -- mail relay
- `RAILS_MASTER_KEY` -- decrypts Rails credentials
- `SECRET_KEY_BASE` -- Rails session signing

## Caddyfile

Uses `{$CADDY_ADDRESS}` env var:
- Dev: `CADDY_ADDRESS=":8080"` -> plain HTTP on port 8080
- Prod: `CADDY_ADDRESS="bonanza.example.com"` -> automatic HTTPS on 80/443

## Volumes

| Volume | Purpose |
|--------|---------|
| `bonanza_postgres_data` | PostgreSQL data (wipe on major PG version bump) |
| `bonanza_elasticsearch_data` | Elasticsearch indices |
| `bonanza_caddy_data` | Caddy TLS certificates |
| `bonanza_node_modules` | Dev only: persistent node_modules |
| `bonanza_rails_storage` | Dev only: ActiveStorage files |
