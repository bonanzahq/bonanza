# Bonanza
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-2-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

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

### Seed users

All seed users share the password `platypus-umbrella-cactus`.

| Email                  | Role   | Admin |
|------------------------|--------|-------|
| `admin@example.com`    | leader | yes   |
| `leader@example.com`   | leader | no    |
| `member@example.com`   | member | no    |
| `guest@example.com`    | guest  | no    |
| `hidden@example.com`   | hidden | no    |

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

TLS is handled by an external reverse proxy (nginx) in front of the Docker
stack. Caddy serves plain HTTP on port 8080 internally. Nginx terminates TLS
using Let's Encrypt certificates managed by certbot.

```
Internet → nginx (TLS on 443) → Caddy (8080) → Rails (3000)
```

Nginx configuration example:

```nginx
server {
    listen 443 ssl;
    server_name bonanza2.fh-potsdam.de;

    ssl_certificate /etc/letsencrypt/live/bonanza.fh-potsdam.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bonanza.fh-potsdam.de/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Why not Caddy auto-HTTPS?** The FH Potsdam network has IPv6 DNS records but
the IPv6 firewall blocks inbound traffic. Let's Encrypt prefers IPv6 and
times out on ACME challenges. See `docs/plans/tls-debugging.md` for details.

### Updating

```bash
# Pull latest image and restart
docker compose pull
docker compose up -d

# Re-download config files if changed upstream
bash deploy.sh
```

## GDPR Compliance

The system implements GDPR data protection requirements for borrower and
staff personal data.

### Data Export

Staff can export a borrower's personal data as JSON from the borrower detail
page. The export includes personal information, lending history, and conduct
records.

### Right to Erasure

Staff can request deletion of a borrower from the borrower detail page:

- **Borrowers with lending history within 7 years**: personal fields are
  anonymized (replaced with placeholders), but lending and conduct records are
  retained for accounting compliance (HGB §257).
- **Borrowers with no recent lending history**: the record is fully destroyed.
- **Borrowers with active lendings**: deletion is blocked until all items are
  returned.

### Automatic Anonymization

Two background jobs run on a weekly schedule:

- **Inactive borrowers**: borrowers with no lending history who haven't been
  updated in 24+ months are anonymized.
- **Old borrowers**: borrowers whose most recent lending is older than 7 years
  are anonymized.

### Audit Logging

Every GDPR action (export, anonymization, deletion request) is recorded in
the `gdpr_audit_logs` table. Each entry tracks the action, the affected
record, and the staff member who triggered it (nil for automated jobs). Audit
logs persist even if the target record is later destroyed.

Query audit logs from the Rails console:

```ruby
GdprAuditLog.all
GdprAuditLog.for_action("anonymize")
GdprAuditLog.for_target(Borrower.find(1))
```

See `AGENTS.md` for project conventions and issue tracking workflow.

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/philippgeuder"><img src="https://avatars.githubusercontent.com/u/2470331?v=4?s=100" width="100px;" alt="Philipp"/><br /><sub><b>Philipp</b></sub></a><br /><a href="https://github.com/bonanzahq/bonanza/commits?author=philippgeuder" title="Code">💻</a> <a href="#design-philippgeuder" title="Design">🎨</a> <a href="#infra-philippgeuder" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#ideas-philippgeuder" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://fabianmoronzirfas.me"><img src="https://avatars.githubusercontent.com/u/315106?v=4?s=100" width="100px;" alt="Fabian Morón Zirfas"/><br /><sub><b>Fabian Morón Zirfas</b></sub></a><br /><a href="https://github.com/bonanzahq/bonanza/commits?author=ff6347" title="Code">💻</a> <a href="#design-ff6347" title="Design">🎨</a> <a href="#infra-ff6347" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#ideas-ff6347" title="Ideas, Planning, & Feedback">🤔</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!