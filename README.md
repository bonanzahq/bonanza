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

See `AGENTS.md` for project conventions and issue tracking workflow.
