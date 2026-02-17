# Bonanza

Equipment lending management system for FH Potsdam. v2

See [docs/SPEC.md](docs/SPEC.md) for the system specification.

## Prerequisites

- Docker and Docker Compose

## Setup

```bash
docker compose up --build
```

This starts all services:

| Service       | Port  | Purpose                        |
|---------------|-------|--------------------------------|
| Caddy         | 8080  | Reverse proxy (app entry point)|
| Rails         | 3000  | Application server (direct)    |
| PostgreSQL    | 5432  | Database                       |
| Elasticsearch | 9200  | Full-text search               |
| Mailpit       | 8025  | Email testing UI               |

On first boot the entrypoint creates the database, loads the schema, seeds
data, and reindexes Elasticsearch. Subsequent boots only run pending
migrations.

Login with `admin@example.com` / `password`.

## Development

Access the app at **http://localhost:8080** (through Caddy).

```bash
# Rails console
docker compose exec rails bundle exec rails console

# Run migrations
docker compose exec rails bundle exec rails db:migrate

# Reseed database
docker compose exec rails bundle exec rails db:seed

# Reindex Elasticsearch
docker compose exec rails bundle exec rails runner "ParentItem.reindex; Borrower.reindex"

# View logs
docker compose logs -f rails

# Rebuild after Gemfile or package.json changes
docker compose up --build rails
```

Emails sent by the app are captured by Mailpit at **http://localhost:8025**.

Source code is mounted as a volume, so code changes are picked up on the next
request (no rebuild needed). Asset changes (JS/CSS) require a container
restart since there is no file watcher in the container.

## Troubleshooting

**Containers stuck in "Created" state:**
Docker Desktop for Mac can get stuck. Kill Docker Desktop processes and
restart.

**"Content missing" or blank pages:**
This is a known Turbo Frame issue, not a Docker problem. See git-bug issues.

**Elasticsearch reindex fails:**
Non-fatal on startup. Run manually:
```bash
docker compose exec rails bundle exec rails runner "ParentItem.reindex; Borrower.reindex"
```

**Stale PID file prevents Puma from starting:**
The entrypoint removes `tmp/pids/server.pid` automatically. If it persists:
```bash
docker compose exec rails rm -f tmp/pids/server.pid
docker compose restart rails
```

**Assets look wrong or missing:**
The entrypoint builds assets on every boot. Force a rebuild:
```bash
docker compose exec rails pnpm build && docker compose exec rails pnpm build:css
```

## Deployment

Production runs from pre-built Docker images. No source code checkout needed
on the server.

### Prerequisites

- Docker and Docker Compose on the server
- A GitHub fine-grained PAT with read-only contents access to this repo

### First-time setup

```bash
# Download deployment files
GITHUB_TOKEN=ghp_xxx bash <(curl -fsSL https://raw.githubusercontent.com/bonanzahq/bonanza/main/deploy.sh)
```

This won't work for private repos without auth. Instead, copy `deploy.sh` to
the server manually and run it:

```bash
GITHUB_TOKEN=ghp_xxx bash deploy.sh
```

The script downloads `docker-compose.yml`, `Caddyfile`,
`elastic_synonyms.txt`, and `example.env` (as `.env`).

Then fill in `.env` with production values (see `example.env` for reference)
and start the stack:

```bash
docker compose up -d
```

On first boot, the entrypoint runs `rake bootstrap:admin` which creates the
initial admin user from `ADMIN_EMAIL` and `ADMIN_PASSWORD` environment
variables. These are required on first deploy and can be removed from `.env`
afterwards.

### TLS / HTTPS

Caddy handles TLS automatically via Let's Encrypt when `CADDY_ADDRESS` is set
to a domain name (e.g. `bonanza2.fh-potsdam.de`). Set it to `:8080` for plain
HTTP (e.g. during initial testing).

**Port requirements:** Only port 443 is exposed. Port 80 is not used because
the FH Potsdam firewall blocks it. Caddy obtains certificates via the
TLS-ALPN-01 challenge (port 443 only). If port 443 is also blocked, see
`docs/plans/tls-debugging.md` for alternatives (DNS-01, institutional certs).

**Troubleshooting:** If Caddy logs show ACME timeout errors, check that no
other process (e.g. nginx) is using port 443:

```bash
sudo ss -tlnp | grep :443
```

To reset Caddy's ACME state and retry certificate provisioning:

```bash
docker compose down
docker volume rm $(docker volume ls -q | grep caddy_data)
docker compose up -d
```

### Updating

```bash
# Pull latest image and restart
docker compose pull
docker compose up -d

# Re-download config files if changed upstream
bash deploy.sh
```

See `AGENTS.md` for project conventions and issue tracking workflow.
