# Deployment Architecture and Troubleshooting

// ABOUTME: Production deployment architecture and common troubleshooting issues
// ABOUTME: Documents nginx → Caddy → Rails request flow and solutions to known problems

## Architecture Overview

Production request flow:

```
Internet → nginx (TLS :443) → Caddy (HTTP :8080) → Rails (:3000)
```

### Components

**nginx** (host system, not containerized)
- TLS termination using certbot/Let's Encrypt certificates
- Proxies to Caddy on port 8080
- Handles IPv6 ACME challenges (Caddy cannot due to firewall)
- See `docs/plans/tls-debugging.md` for why nginx is needed

**Caddy** (Docker service)
- Internal reverse proxy within Docker network
- Plain HTTP on :8080 (TLS already terminated by nginx)
- Routes to Rails container on port 3000
- Configured via `CADDY_ADDRESS` environment variable

**Rails** (Docker service)
- Runs via Puma web server on port 3000
- Behind Caddy, not exposed directly to Internet
- Needs `config.assume_ssl = true` because TLS is upstream

**PostgreSQL** (Docker service)
- Database on port 5432
- Configured via component env vars: `DB_HOST`, `DB_PASSWORD`, etc.

**Elasticsearch** (Docker service)
- Search on port 9200
- Configured via component env vars: `ES_HOST`, `ES_PASSWORD`
- Passwords URL-encoded automatically by Rails entrypoint

## Environment Variables

See `example.env` for the full template.

### Database and Search

Connection details use **component-based configuration**, not connection URLs:

```bash
DB_HOST=postgres
DB_USER=bonanza
DB_PASSWORD=your-password-here
DB_NAME=bonanza_production

ES_HOST=http://elasticsearch:9200
ES_PASSWORD=your-es-password
```

**Important:** Passwords are URL-encoded automatically by the Rails entrypoint script via Ruby's `URI.encode_www_form_component`. Don't manually URL-encode them in `.env`.

The old approach (URLs in `docker-compose.yml`) broke with special characters in passwords. The current component-based approach is robust.

### Caddy Configuration

```bash
CADDY_ADDRESS=:8080
```

Caddy listens on plain HTTP because TLS is terminated by nginx upstream. Do NOT use `:443` or auto-HTTPS modes.

### Rails Application Settings

```bash
APP_HOST=bonanza.fh-potsdam.de
APP_PORT=443
APP_PROTOCOL=https
RAILS_ENV=production
SECRET_KEY_BASE=generated-via-rails-secret
```

`APP_HOST`, `APP_PORT`, `APP_PROTOCOL` control URL generation in emails and notifications. These must reflect the public-facing URL, not the internal container network.

### First Deploy Only

```bash
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=secure-password
```

Used by `lib/tasks/bootstrap.rake` on first deploy to create the admin user and default department. Not needed for subsequent deploys.

## First Deploy

### Setup

1. Run `deploy.sh` to download config files:
   ```bash
   curl -O https://raw.githubusercontent.com/bonanzahq/bonanza/main/deploy.sh
   chmod +x deploy.sh
   ./deploy.sh
   ```

2. Fill in `.env` with passwords and configuration

3. Start services:
   ```bash
   docker compose up -d
   ```

### What Happens on Startup

The Rails container entrypoint (`docker/entrypoint.sh`) performs:

1. Wait for PostgreSQL to accept connections
2. Wait for Elasticsearch to respond
3. Run `rails db:prepare` (creates schema if new database)
4. Run `rails bootstrap:admin` (creates admin user, default department, legal texts)
5. Reindex Elasticsearch (ParentItem, Borrower)
6. Start Puma via `foreman start`

Check startup progress: `docker compose logs -f rails`

## Known Issues and Solutions

### 1. CSRF / InvalidAuthenticityToken on login

**Symptom:**
```
HTTP Origin header (https://bonanza.fh-potsdam.de) didn't match request.base_url (http://bonanza.fh-potsdam.de:8080)
```

**Cause:**  
Rails doesn't know it's behind TLS. nginx sends `X-Forwarded-Proto: https` but Rails doesn't automatically trust it.

**Fix:**  
Add to `config/environments/production.rb`:
```ruby
config.assume_ssl = true
```

**Not** `config.force_ssl = true` – that causes redirect loops because Caddy sees plain HTTP and keeps redirecting.

### 2. Let's Encrypt ACME challenges fail

**Symptom:**  
Caddy logs show:
```
Timeout during connect (likely firewall problem)
```

**Cause:**  
FH Potsdam DNS has AAAA records but IPv6 firewall blocks inbound traffic. Let's Encrypt prefers IPv6 when available, so ACME challenges time out.

**Fix:**  
Use nginx with certbot for TLS instead of Caddy's auto-HTTPS. See `docs/plans/tls-debugging.md` for full investigation and solution.

### 3. Elasticsearch connection hangs

**Symptom:**  
Rails logs stuck at:
```
Waiting for Elasticsearch at http://elasticsearch:9200...
```

**Cause:**  
- `ES_HOST` or `ES_PASSWORD` not set in `.env`
- Password mismatch (Elasticsearch initialized with different password)

**Fix:**  
Ensure `ES_PASSWORD` matches the password Elasticsearch was initialized with. If the password was changed after first run, Elasticsearch won't accept the new one.

To reset Elasticsearch with a new password:
```bash
docker compose down
docker volume rm $(docker volume ls -q | grep elasticsearch)
docker compose up -d
```

### 4. Passwords with special characters break connections

**Symptom:**  
Database or Elasticsearch connection errors despite correct passwords.

**Cause:**  
Old approach interpolated passwords directly into URLs in `docker-compose.yml`. Characters like `@`, `#`, `%` broke URL parsing.

**Fix:**  
Current deployment uses component env vars (`DB_PASSWORD`, `ES_PASSWORD`). The Rails entrypoint URL-encodes them via Ruby's `URI.encode_www_form_component` before constructing connection URLs.

No manual URL-encoding needed in `.env`.

### 5. Port 443/80 conflicts

**Symptom:**
```
nginx: [emerg] bind() failed (98: Address already in use)
```

**Cause:**  
Another process is using port 443 or 80 (old nginx instance, Docker from previous deploy, other web server).

**Fix:**  
Find the process:
```bash
sudo ss -tlnp | grep :443
```

Stop it:
```bash
sudo systemctl stop nginx  # If it's the old nginx
# or
sudo kill <PID>
```

### 6. Rails container keeps restarting

**Symptom:**  
`docker compose ps` shows Rails container as "unhealthy" or constantly restarting.  
Logs show repeated "Waiting for PostgreSQL/Elasticsearch" messages.

**Cause:**  
- Dependencies not ready (PostgreSQL or Elasticsearch failed to start)
- Wrong Docker image (old image without component-based URL construction)

**Fix:**  
Pull latest image and restart:
```bash
docker compose pull rails
docker compose up -d
```

Check dependency status:
```bash
docker compose ps
docker compose logs postgres
docker compose logs elasticsearch
```

### 7. 502 Bad Gateway

**Symptom:**  
nginx returns `502 Bad Gateway` when accessing the site.

**Cause:**  
Caddy cannot reach Rails (Rails still starting, crashed, or bound to wrong port).

**Fix:**  
Check Rails status:
```bash
docker compose ps
docker compose logs rails
```

Verify Caddy can reach Rails:
```bash
docker compose exec caddy wget -O- http://rails:3000
```

### 8. Caddy ACME state corrupted

**Symptom:**  
Caddy keeps retrying failed ACME challenges even after fixing configuration.

**Cause:**  
Caddy stores ACME state in a Docker volume. Corrupted state persists across restarts.

**Fix:**  
Wipe Caddy data volume:
```bash
docker compose down
docker volume rm $(docker volume ls -q | grep caddy)
docker compose up -d
```

## Full Reset

To completely reset the deployment (WARNING: destroys all data):

```bash
docker compose down -v
docker compose up -d
```

The `-v` flag removes **all volumes** including:
- PostgreSQL database
- Elasticsearch indexes
- Caddy configuration

Use only when starting fresh or debugging persistent state issues.

## Useful Commands

### Check service status
```bash
docker compose ps
```

### View logs
```bash
docker compose logs -f rails
docker compose logs -f caddy
docker compose logs -f postgres
docker compose logs -f elasticsearch
```

### Rails console
```bash
docker compose exec rails bundle exec rails console
```

### Check what's using a port
```bash
sudo ss -tlnp | grep :443
sudo ss -tlnp | grep :80
```

### Reindex Elasticsearch manually
```bash
docker compose exec rails bundle exec rails runner "ParentItem.reindex; Borrower.reindex"
```

### Restart a single service
```bash
docker compose restart rails
```

### Pull latest images
```bash
docker compose pull
docker compose up -d
```

### Verify nginx configuration
```bash
sudo nginx -t
```

### Reload nginx (after config changes)
```bash
sudo systemctl reload nginx
```

## Related Documentation

- `docs/plans/tls-debugging.md` - Full investigation of TLS/ACME issues
- `example.env` - Template for environment variables
- `docker-compose.yml` - Service configuration
- `docker/entrypoint.sh` - Rails container startup script
