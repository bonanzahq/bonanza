# B1 Containerization Session

## What was done

Implemented containerization for the full application stack:

- `.dockerignore` - excludes git, node_modules, tmp, logs, docs, tests, secrets
- `config/initializers/elasticsearch.rb` - fixed to use `||=` so Docker's `ELASTICSEARCH_URL` takes precedence; removed hardcoded CA fingerprint; SSL config only applied when URL is HTTPS
- `Caddyfile` - reverse proxy on `:8080` to `rails:3000`, security headers, JSON logging, `auto_https off` for development
- `docker-entrypoint.sh` - waits for PG and ES, creates tmp dirs, builds assets, runs `db:prepare`, reindexes ES, execs into CMD
- `Dockerfile` - single-stage Debian build with Ruby 3.1.2, Node 20 (nodesource), pnpm 10 (corepack), bundle install, pnpm install, asset compilation
- `docker-compose.yml` - 5 services: db (postgres:15-alpine), elasticsearch (8.4.0), rails, caddy (2-alpine), mailpit

## Decisions

- **Single-stage Dockerfile** instead of multi-stage: for development, simplicity wins. Production optimization deferred to CI/CD phase.
- **Node 20 in Docker** despite mise.toml specifying Node 24: Node 20 LTS is more reliable for Docker via nodesource. The JS tooling (esbuild 0.14, sass 1.48) doesn't need newer Node.
- **`db:prepare` with non-fatal error handling**: `db:prepare` is the right command (creates DB + loads schema on first boot, migrates on subsequent boots). Seed failures are caught and don't prevent Puma from starting.
- **Asset build in entrypoint**: the source volume mount (`.:/app`) overlays the image filesystem, so assets compiled during `docker build` are lost. The entrypoint runs `pnpm build && pnpm build:css` before starting Puma.
- **Elasticsearch reindex on startup**: Searchkick requires indexes to exist. Reindex is non-fatal so the app still starts if it fails.
- **No `env_file`** in docker-compose: Docker Compose v2.2.3 on this machine doesn't support optional env_file syntax. All required env vars set directly in `environment` section.
- **Port 8080** for Caddy: avoids conflict with Bonanza v1 on shared host, no privileged port.

## Issues encountered

- **Docker Desktop daemon stuck**: containers got stuck in "Created" state and never transitioned to "Running". Required killing Docker Desktop processes and restarting. Appears to be a Docker Desktop for Mac issue (v20.10.12). Intermittent.
- **Puma PID file**: volume mount overlays the image filesystem, so `tmp/pids/` didn't exist. Fixed by creating directories in entrypoint.
- **Seed data validation**: seed lending records have dates in the past, failing validation at `db/seeds.rb:33`. Seeds partially succeed (department, user, items created) but lending record fails. Filed as git-bug `5dbb591`.
- **Missing assets on startup**: volume mount overwrites image-built assets with empty host directory (assets are in `.gitignore`). Fixed by building assets in entrypoint.
- **Empty schema.rb in worktree**: the `feat-containerization` worktree had `schema.rb` with `version: 0` (no tables) while `main` had the full schema. This caused `db:schema:load` to create an empty database. Fixed by restoring schema.rb from main.
- **Elasticsearch reindex failure on empty DB**: reindex failed when tables didn't exist. Made non-fatal so Puma starts regardless.

## Bugs filed

- `5dbb591` - Seed data has stale dates that fail validation
- `1516f52` - Department model allows duplicate names (no uniqueness validation)

## Verification results

All passing:
- `docker compose build` succeeds
- `docker compose up` starts all 5 services
- db, elasticsearch, rails health checks pass
- App accessible at `:8080` (Caddy) and `:3000` (direct)
- `/up` health endpoint returns 200
- Mailpit UI at `:8025` returns 200
- Containers survive `docker compose restart`
- Login works with `admin@example.com` / `password`

## Remaining work

- Seed data needs dates fixed (git-bug `5dbb591`)
- Department uniqueness validation (git-bug `1516f52`)
- Production optimization (multi-stage build, non-root user) deferred to CI/CD phase
- docker-compose.override.yml for development-specific overrides
- Docker Compose should be upgraded from v2.2.3 for better features (optional env_file, etc.)
