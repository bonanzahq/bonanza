# B1 Containerization Session

## What was done

Implemented containerization for the full application stack:

- `.dockerignore` - excludes git, node_modules, tmp, logs, docs, tests, secrets
- `config/initializers/elasticsearch.rb` - fixed to use `||=` so Docker's `ELASTICSEARCH_URL` takes precedence; removed hardcoded CA fingerprint; SSL config only applied when URL is HTTPS
- `Caddyfile` - reverse proxy on `:8080` to `rails:3000`, security headers, JSON logging, `auto_https off` for development
- `docker-entrypoint.sh` - waits for PG and ES, creates tmp dirs, runs `db:create` + `db:migrate`, execs into CMD
- `Dockerfile` - single-stage Debian build with Ruby 3.1.2, Node 20 (nodesource), pnpm 10 (corepack), bundle install, pnpm install, asset compilation
- `docker-compose.yml` - 5 services: db (postgres:15-alpine), elasticsearch (8.4.0), rails, caddy (2-alpine), mailpit

## Decisions

- **Single-stage Dockerfile** instead of multi-stage: for development, simplicity wins. Production optimization deferred to CI/CD phase.
- **Node 20 in Docker** despite mise.toml specifying Node 24: Node 20 LTS is more reliable for Docker via nodesource. The JS tooling (esbuild 0.14, sass 1.48) doesn't need newer Node.
- **`db:create` + `db:migrate`** instead of `db:prepare`: seeds fail due to stale dates in seed data (lending duration validation). Seeds should be run manually.
- **No `env_file`** in docker-compose: Docker Compose v2.2.3 on this machine doesn't support optional env_file syntax. All required env vars set directly in `environment` section.
- **Port 8080** for Caddy: avoids conflict with Bonanza v1 on shared host, no privileged port.

## Issues encountered

- **Docker Desktop daemon stuck**: containers got stuck in "Created" state and never transitioned to "Running". Required killing Docker Desktop processes and restarting. Appears to be a Docker Desktop for Mac issue (v20.10.12). Intermittent.
- **Puma PID file**: volume mount overlays the image filesystem, so `tmp/pids/` didn't exist. Fixed by creating directories in entrypoint.
- **Seed data validation**: `db:prepare` runs seeds on first boot, but seed lending records have dates in the past, failing validation. Switched to explicit `db:create` + `db:migrate`.

## Verification results

All passing:
- `docker compose build` succeeds
- `docker compose up` starts all 5 services
- db, elasticsearch, rails health checks pass
- App accessible at `:8080` (Caddy) and `:3000` (direct)
- `/up` health endpoint returns 200
- Mailpit UI at `:8025` returns 200
- No errors in `docker compose logs rails`
- Containers survive `docker compose restart`

## Remaining work

- Seed data needs dates fixed (separate issue)
- Production optimization (multi-stage build, non-root user) deferred to CI/CD phase
- docker-compose.override.yml for development-specific overrides
- Docker Compose should be upgraded from v2.2.3 for better features (optional env_file, etc.)
