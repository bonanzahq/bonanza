# Production Deployment

## Objective

Manual first-time deployment of Bonanza to the FH Potsdam server. This
covers server setup and initial go-live. CI/CD automation comes later (b4).

## TLS Strategy (Decision Needed)

The app is VPN-only. Let's Encrypt won't work because the ACME HTTP
challenge requires public internet access to port 80.

Options:

| Option | Pros | Cons |
|--------|------|------|
| Caddy internal TLS (`tls internal`) | Zero config, HTTPS works | Browser shows cert warning |
| FHP internal CA cert | Trusted by university machines | Need to get cert from IT |
| Plain HTTP | Simplest | No encryption (VPN may be sufficient) |
| DNS ACME challenge | Real cert, no warnings | Needs DNS API access (unlikely) |

**Recommendation:** Start with Caddy internal TLS. If FHP IT provides a
CA cert later, mount it into the Caddy container. If the VPN is considered
trusted, plain HTTP is fine too.

Caddy internal TLS requires adding `tls internal` to the Caddyfile site
block. This can be toggled via an env var or a one-line Caddyfile change
on the server.

**This decision needs Fabian + FHP IT input.**

## Prerequisites

- Ubuntu/Debian server with SSH + sudo access
- At least 4GB RAM (ES needs 1GB heap + overhead)
- Docker Engine 24+ and Docker Compose v2
- Git
- Ports 80 and 443 available (stop existing nginx/Apache)
- Hostname or IP reachable within VPN
- FHP SMTP relay details

## Deployment Steps

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
```

### 2. Stop existing web server

```bash
sudo systemctl stop nginx    # or apache2
sudo systemctl disable nginx # prevent restart on reboot
```

This takes v1 down. Coordinate timing with data migration (d1).

### 3. Clone the repo

```bash
sudo mkdir -p /opt/bonanza
sudo chown $USER:$USER /opt/bonanza
cd /opt/bonanza
git clone git@github.com:bonanzahq/bonanza.git .
git checkout <release-tag-or-branch>
```

### 4. Create .env file

```bash
cd /opt/bonanza
cat > .env <<'EOF'
POSTGRES_PASSWORD=<generate: openssl rand -base64 32>
ELASTIC_PASSWORD=<generate: openssl rand -base64 32>
SECRET_KEY_BASE=<generate: openssl rand -hex 64>
RAILS_MASTER_KEY=<from config/master.key>
APP_HOST=<hostname, e.g. bonanza.fh-potsdam.de>
SMTP_HOST=<FHP SMTP relay>
SMTP_PORT=587
EOF
chmod 600 .env
```

### 5. Build and start

```bash
docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml up -d
```

The entrypoint automatically:
- Waits for PostgreSQL and Elasticsearch
- Creates the database if it doesn't exist
- Runs migrations (fails hard on errors)

### 6. Verify

```bash
# Check all services
docker compose -f docker-compose.yml ps

# Health check (use -k for self-signed cert)
curl -k https://<APP_HOST>/up

# Check logs
docker compose -f docker-compose.yml logs -f rails
```

### 7. Initial data

For a fresh install (no v1 migration):
```bash
docker compose -f docker-compose.yml exec rails \
  bundle exec rails db:seed RAILS_ENV=production
```

For v1 data migration: follow the d1 plan.

### 8. Setup backups

```bash
mkdir -p /opt/bonanza/backups

# Add daily cron job
(crontab -l 2>/dev/null; echo "0 2 * * * cd /opt/bonanza && ./bin/backup >> /var/log/bonanza-backup.log 2>&1") | crontab -
```

### 9. Reindex Elasticsearch

```bash
docker compose -f docker-compose.yml exec rails \
  bundle exec rails runner "ParentItem.reindex; Borrower.reindex" \
  RAILS_ENV=production
```

## Updating (Before CI/CD)

```bash
cd /opt/bonanza
git pull
docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml up -d
# Entrypoint runs db:migrate automatically
```

## Rollback

```bash
cd /opt/bonanza
git checkout <previous-tag>
docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml up -d

# If migration needs reverting:
docker compose -f docker-compose.yml exec rails \
  bundle exec rails db:rollback RAILS_ENV=production
```

## Monitoring

```bash
# Service status
docker compose -f docker-compose.yml ps

# Live logs
docker compose -f docker-compose.yml logs -f rails

# Resource usage
docker stats

# Manual health check
curl -k https://<APP_HOST>/up
```

Log rotation is handled by Docker's json-file driver (10MB x 5 files,
configured in docker-compose.yml).

## Coordination

- **Stopping nginx/Apache kills v1.** Must coordinate timing with d1 (data
  migration). Option: run v2 on different ports during migration, then switch.
- **VPN access** needs FHP IT coordination (d2).
- **SMTP relay** details needed from FHP IT.

## Open Questions

- TLS strategy (see decision table above)
- Server hostname/IP within VPN
- FHP SMTP relay address and credentials
- sudo access or will FHP IT install Docker?
- Deploy empty first and migrate data later, or do both in one cutover?
