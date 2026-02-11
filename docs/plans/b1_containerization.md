# Containerization Plan

## Objective

Containerize the Bonanza Redux application with Docker to provide a consistent development and deployment environment.

## Technology Stack

- **Application**: Rails 7.0.4.2 with Ruby 3.1.2 (containerize with current
  versions first; the dependency update step upgrades to Rails 8.x / Ruby 3.4+)
- **Version Management**: mise (for Ruby, Node.js, pnpm)
- **Package Manager**: pnpm (not yarn)
- **Database**: PostgreSQL 15
- **Search**: Elasticsearch 8.4
- **Reverse Proxy**: Caddy
- **Email Testing**: Mailpit (development only)
- **Container Orchestration**: Docker Compose

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                      Caddy                          │
│              (Reverse Proxy / HTTPS)                │
└─────────────────┬───────────────────────────────────┘
                  │
                  ├──> Rails App (Puma)
                  ├──> Mailpit UI (http://localhost:8025)
                  │
┌─────────────────┴───────────────────────────────────┐
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  Rails App   │  │ PostgreSQL   │  │Elasticsearch│
│  │    (Puma)    │  │      15      │  │     8.4    │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                 │        │
│         │          ┌──────┴──────┐          │        │
│         └─────────>│   Mailpit   │          │        │
│                    │ (SMTP + UI) │          │        │
│  ┌──────────────┐  └─────────────┘          │        │
│  │  Scheduler   │                            │        │
│  │ (Clockwork)  ├────────────────────────────┘        │
│  └──────────────┘  ─────> Sends emails via Mailpit   │
│                    Docker Network                     │
└───────────────────────────────────────────────────────┘
```

## Container Services

### 1. Rails Application Container (Web)
**Purpose**: Run the Rails application with Puma web server

**Base Image**: `ruby:3.1.2-alpine` (lightweight) or `ruby:3.1.2` (full)

**Requirements**:
- Install mise for version management
- Install system dependencies:
  - PostgreSQL client libraries (libpq-dev)
  - Build tools (gcc, make, g++)
- Install Ruby gems via Bundler (version from mise)
- Install JavaScript dependencies via pnpm (version from mise)
- Precompile assets (JS via esbuild, CSS via Sass)
- Run database migrations on startup (conditional)
- Start Puma server

**Environment Variables**:
- `RAILS_ENV` (production/development)
- `DATABASE_URL` (PostgreSQL connection string)
- `ELASTICSEARCH_URL` (Elasticsearch endpoint)
- `RAILS_MASTER_KEY` or credentials file for production
- `RAILS_MAX_THREADS`
- `BONANZA_REDUX_DATABASE_PASSWORD`
- `SMTP_HOST=mailpit` (development only)
- `SMTP_PORT=1025` (development only)
- `SMTP_DOMAIN=localhost` (development only)

**Volumes**:
- `/app/storage` - ActiveStorage files
- `/app/log` - Application logs
- `/app/tmp` - Temporary files and PIDs

**Exposed Ports**:
- `3000` (internal, proxied by Caddy)

**Health Check**:
- Endpoint: `GET /up` (exists in routes.rb:2)

### 2. PostgreSQL Container
**Purpose**: Database storage

**Base Image**: `postgres:15-alpine`

**Requirements**:
- Enable `plpgsql` extension (enabled by default)
- Initialize database on first run
- Persist data across container restarts

**Environment Variables**:
- `POSTGRES_USER=bonanza_redux`
- `POSTGRES_PASSWORD` (from secrets)
- `POSTGRES_DB=bonanza_redux_production`

**Volumes**:
- `/var/lib/postgresql/data` - Database data directory

**Exposed Ports**:
- `5432` (internal only, not exposed to host)

**Health Check**:
- `pg_isready -U bonanza_redux`

### 3. Elasticsearch Container
**Purpose**: Full-text search for ParentItems and Borrowers

**Base Image**: `docker.elastic.co/elasticsearch/elasticsearch:8.4.0`

**Requirements**:
- Copy `elastic_synonyms.txt` to config directory
- Configure index template with single shard, zero replicas
- Disable security for development (enable for production)
- Set JVM heap size appropriately

**Environment Variables**:
- `discovery.type=single-node`
- `xpack.security.enabled=false` (dev) / `true` (prod)
- `ES_JAVA_OPTS=-Xms512m -Xmx512m` (adjust based on available memory)

**Volumes**:
- `/usr/share/elasticsearch/data` - Index data
- `/usr/share/elasticsearch/config/elastic_synonyms.txt` - Synonyms file

**Exposed Ports**:
- `9200` (internal only)

**Health Check**:
- `curl -f http://localhost:9200/_cluster/health || exit 1`

### 4. Caddy Container
**Purpose**: Reverse proxy with automatic HTTPS

**Base Image**: `caddy:2-alpine`

**Requirements**:
- Configure reverse proxy to Rails app
- Serve static assets directly (optional optimization)
- Handle HTTPS/TLS certificates automatically
- Add security headers

**Configuration** (Caddyfile):
```
{
    # Global options
    auto_https off  # For development
}

:80 {
    # Reverse proxy to Rails
    reverse_proxy rails:3000

    # Logging
    log {
        output stdout
        format json
    }

    # Security headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# Mailpit UI (development only)
:8025 {
    reverse_proxy mailpit:8025

    log {
        output stdout
        format json
    }
}
```

**Volumes**:
- `/data` - Certificate storage (for production HTTPS)
- `/config` - Caddyfile configuration

**Exposed Ports**:
- `80` (HTTP) - mapped to host
- `443` (HTTPS) - mapped to host (production)
- `8025` (Mailpit UI) - mapped to host (development only)

### 5. Mailpit Container
**Purpose**: Email testing and debugging (development/staging only)

**Base Image**: `axllent/mailpit:latest`

**Requirements**:
- Capture all emails sent from Rails application
- Provide web UI for viewing emails
- Support for viewing HTML and text versions
- No authentication required (development only)

**Environment Variables**:
- `MP_SMTP_AUTH_ACCEPT_ANY=1` - Accept any authentication
- `MP_SMTP_AUTH_ALLOW_INSECURE=1` - Allow insecure connections

**Volumes**:
- None required (emails stored in memory)

**Exposed Ports**:
- `1025` (SMTP) - internal only, used by Rails
- `8025` (HTTP) - web UI, proxied by Caddy

**Health Check**:
- `wget -q --spider http://localhost:8025 || exit 1`

**Notes**:
- Should only be included in development/staging environments
- Not needed in production (use real SMTP server)
- Automatically captures all SMTP traffic on port 1025

### 6. Scheduler Container
**Purpose**: Run scheduled tasks for automated email notifications and cleanup

**Base Image**: Same as Rails application (shares codebase)

**Requirements**:
- Run clockwork gem for task scheduling
- Execute rake tasks on schedule
- No HTTP server needed
- Logs to stdout for Docker logging

**Environment Variables**:
- Same as Rails application (DATABASE_URL, ELASTICSEARCH_URL, SMTP settings, etc.)
- `TZ=Europe/Berlin` - Timezone for scheduling

**Volumes**:
- None required (stateless, reads from database)

**Exposed Ports**:
- None (no external access needed)

**Health Check**:
- None required (or check if process is running)

**Command**:
- `bundle exec clockwork config/clock.rb`

**Scheduled Tasks** (see email-notifications.md for details):
- Daily return reminders (5 days before due)
- Final return reminders (1 day before due)
- Overdue notifications
- Daily staff summary emails
- Automatic ban expiration cleanup

**Notes**:
- Runs continuously, not on-demand
- Shares same Docker image as Rails application
- Must have access to database and SMTP
- Container restart policy: `unless-stopped`
- View logs: `docker-compose logs -f scheduler`

## Docker Compose Structure

**Services**:
1. `db` - PostgreSQL 15
2. `elasticsearch` - Elasticsearch 8.4
3. `rails` - Rails application (web)
4. `worker` - Background job processor (Solid Queue) - see plan c1
5. `scheduler` - Scheduled tasks (clockwork)
6. `caddy` - Reverse proxy
7. `mailpit` - Email testing (development only)

### 7. Worker Container (see plan c1)
**Purpose**: Process background jobs (emails, async tasks)

**Base Image**: Same as Rails application (shares codebase)

**Command**: `bundle exec rake solid_queue:start`

**Environment Variables**: Same as Rails application

**Resource Limits**:
- Memory: 256MB
- CPU: 0.5

**Health Check**: Monitor job queue depth

**Notes**:
- Processes jobs queued by Rails app
- Required for async email delivery
- See `docs/plans/c1_background-jobs.md` for details

**Networks**:
- `bonanza_network` (bridge) - Internal communication between services

**Volumes**:
- `postgres_data` - Persistent database storage
- `elasticsearch_data` - Persistent search index storage
- `caddy_data` - Persistent certificates and config
- `rails_storage` - Persistent uploaded files

## Build Strategy

### Multi-stage Dockerfile for Rails

**Stage 1: Builder**
- Install mise for version management
- Install build dependencies
- Install gems with `bundle install --deployment --without development test`
- Install Node.js dependencies with `pnpm install --frozen-lockfile`
- Precompile assets with `pnpm build && pnpm build:css`
- Run `rails assets:precompile`

**Stage 2: Runtime**
- Copy compiled gems from builder
- Copy precompiled assets from builder
- Copy application code
- Install only runtime dependencies
- Set up non-root user for security
- Define entrypoint script for migrations and server startup

### Asset Compilation

**JavaScript**:
- Build with esbuild: `pnpm build`
- Output to `app/assets/builds/`

**CSS**:
- Compile Sass: `pnpm build:css`
- Output to `app/assets/builds/application.css`

**Rails Assets**:
- Precompile: `rails assets:precompile`
- Note: README mentions adding PurgeCSS before precompiling (TODO item)

## Initialization and Startup Sequence

### First-time Setup
1. Start PostgreSQL container
2. Wait for PostgreSQL to be ready (health check)
3. Start Elasticsearch container
4. Wait for Elasticsearch to be ready (health check)
5. Start Rails container:
   - Run `bundle exec rails db:create` (if database doesn't exist)
   - Run `bundle exec rails db:migrate`
   - Run `bundle exec rails db:seed` (optional, for development)
   - Reindex Elasticsearch: `ParentItem.reindex && Borrower.reindex`
6. Start Caddy container
7. Apply Elasticsearch index template (via curl or initialization script)

### Normal Startup
1. Start all services via `docker-compose up`
2. Rails entrypoint script:
   - Wait for database connection
   - Run pending migrations: `bundle exec rails db:migrate`
   - Start Puma: `bundle exec puma -C config/puma.rb`

## Entrypoint Scripts

### Rails Entrypoint (`docker-entrypoint.sh`)
```bash
#!/bin/sh
set -e

# Wait for PostgreSQL
until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

# Wait for Elasticsearch
until curl -f http://$ELASTICSEARCH_HOST:9200/_cluster/health; do
  echo "Waiting for Elasticsearch..."
  sleep 2
done

# Run migrations
bundle exec rails db:migrate

# Execute CMD (start Puma)
exec "$@"
```

### Elasticsearch Initialization Script
```bash
#!/bin/sh
# Apply index template for single shard, zero replicas
curl -XPUT "http://elasticsearch:9200/_template/default_template" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["*"],
    "settings": {
      "index": {
        "number_of_replicas": 0,
        "number_of_shards": 1
      }
    }
  }'

# Copy synonyms file to config
cp /usr/share/elasticsearch/config/elastic_synonyms.txt \
   /usr/share/elasticsearch/config/analysis/elastic_synonyms.txt
```

## Environment Configuration

### Development Environment
- Use `.env` file with `docker-compose.yml`
- Mount source code as volume for live reloading
- Expose database and Elasticsearch ports for debugging
- Disable Caddy HTTPS (use HTTP only)
- Keep Rails in development mode

### Production Environment
- Use environment variables from secrets management
- No source code volumes (baked into image)
- Enable Caddy HTTPS with automatic certificates
- Rails in production mode
- Set appropriate resource limits

## Security Considerations

1. **Secrets Management**:
   - Never commit `.env` files with real credentials
   - Use Docker secrets or external secrets management in production
   - Rails credentials encrypted with `RAILS_MASTER_KEY`

2. **User Permissions**:
   - Run Rails app as non-root user inside container
   - Use read-only root filesystem where possible

3. **Network Isolation**:
   - Only Caddy exposes ports to host
   - Database and Elasticsearch on internal network only
   - Use Docker network policies for strict isolation

4. **Elasticsearch Security**:
   - Enable X-Pack security in production
   - Use authentication for Elasticsearch API
   - Restrict network access

## Data Persistence and Backups

### PostgreSQL Backups
- Schedule `pg_dump` via cron or external backup tool
- Store backups outside container volumes
- Test restore procedures regularly

### Elasticsearch Backups
- Configure snapshot repository
- Schedule periodic snapshots
- Store in S3 or other object storage

### ActiveStorage Files
- Volume for `storage/` directory
- Consider S3 or object storage for production

## Resource Allocation

### Recommended Minimum Resources
- **Rails**: 512MB RAM, 1 CPU
- **Scheduler**: 256MB RAM, 0.5 CPU
- **PostgreSQL**: 512MB RAM, 1 CPU
- **Elasticsearch**: 1GB RAM (512MB heap), 1 CPU
- **Caddy**: 128MB RAM, 0.5 CPU
- **Mailpit**: 64MB RAM, 0.25 CPU (development only)

### Production Scaling
- Increase Rails instances behind Caddy load balancer
- Increase PostgreSQL resources based on load
- Adjust Elasticsearch heap to 50% of container memory (max 32GB)

## Development Workflow

### Local Development with Docker
```bash
# Start all services
docker-compose up

# Run migrations
docker-compose exec rails bundle exec rails db:migrate

# Access Rails console
docker-compose exec rails bundle exec rails console

# Run seeds
docker-compose exec rails bundle exec rails db:seed

# View logs
docker-compose logs -f rails

# Rebuild after Gemfile changes
docker-compose build rails

# Access Mailpit UI for email testing
open http://localhost:8025
```

### Asset Watching for Development
- Option 1: Run asset watchers inside Rails container
- Option 2: Run asset watchers on host, mount compiled assets
- Recommendation: Use separate service in docker-compose for asset building

## Files to Create

### Required Files
1. `Dockerfile` - Multi-stage Rails application image
2. `docker-compose.yml` - Service orchestration
3. `.dockerignore` - Exclude unnecessary files from build context
4. `docker-entrypoint.sh` - Rails initialization script
5. `Caddyfile` - Reverse proxy configuration
6. `.env.example` - Template for environment variables
7. `docker-compose.override.yml.example` - Development overrides template
8. `config/elasticsearch_init.sh` - Elasticsearch setup script

### Configuration Updates
1. Update `config/database.yml` - Support `DATABASE_URL` environment variable
2. Update `config/puma.rb` - Bind to 0.0.0.0 for container networking
3. Add `config/initializers/elasticsearch.rb` - Configure Searchkick with `ENV['ELASTICSEARCH_URL']`
4. Update `config/environments/development.rb` - Configure SMTP settings for Mailpit
5. Update README - Add Docker setup instructions

## Implementation Phases

### Phase 1: Basic Containerization
- [ ] Create Dockerfile for Rails application
- [ ] Create docker-compose.yml with all services
- [ ] Create .dockerignore
- [ ] Create docker-entrypoint.sh
- [ ] Test local build and startup

### Phase 2: Service Configuration
- [ ] Configure PostgreSQL with proper initialization
- [ ] Configure Elasticsearch with synonyms and templates
- [ ] Configure Mailpit for email testing
- [ ] Create Caddyfile for reverse proxy
- [ ] Wire up all services in docker-compose

### Phase 3: Asset Pipeline
- [ ] Implement multi-stage build for assets
- [ ] Configure esbuild and Sass compilation
- [ ] Test asset precompilation in container
- [ ] Optional: Implement PurgeCSS (from TODO list)

### Phase 4: Development Experience
- [ ] Create docker-compose.override.yml for development
- [ ] Add volume mounts for live code reloading
- [ ] Document development workflow
- [ ] Create helper scripts for common tasks

### Phase 5: Production Readiness
- [ ] Implement health checks for all services
- [ ] Configure resource limits
- [ ] Enable Elasticsearch security
- [ ] Configure Caddy HTTPS for production
- [ ] Document backup and restore procedures
- [ ] Add monitoring and logging configuration

### Phase 6: Documentation and Testing
- [ ] Update README.md with Docker instructions
- [ ] Create .env.example with all required variables
- [ ] Test complete setup from scratch
- [ ] Document troubleshooting procedures

---

## Backup and Restore Procedures

### Database Backup

**Automated daily backups:**
```bash
# Create backup script: /opt/bonanza/backup/backup.sh
#!/bin/bash
set -e

BACKUP_DIR="/opt/bonanza/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker exec $(docker compose ps -q db) \
  pg_dump -U bonanza bonanza_production | gzip > "$BACKUP_DIR/db_${DATE}.sql.gz"

# Remove old backups
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: db_${DATE}.sql.gz"
```

**Schedule via cron:**
```bash
# crontab -e
0 2 * * * /opt/bonanza/backup/backup.sh >> /var/log/bonanza_backup.log 2>&1
```

### Database Restore

```bash
# Restore from backup
gunzip < /opt/bonanza/backups/db_20240101.sql.gz | \
  docker exec -i $(docker compose ps -q db) \
  psql -U bonanza bonanza_production
```

### Elasticsearch Backup

Elasticsearch data can be recreated by reindexing from PostgreSQL:
```bash
docker compose exec rails bundle exec rails runner "
  ParentItem.reindex
  Borrower.reindex
"
```

For large datasets, configure Elasticsearch snapshots to a shared filesystem or S3.

### Volume Backups

```bash
# Backup all persistent volumes
docker run --rm \
  -v bonanza_postgres_data:/data \
  -v /opt/bonanza/backups:/backup \
  alpine tar czf /backup/postgres_$(date +%Y%m%d).tar.gz /data

docker run --rm \
  -v bonanza_rails_storage:/data \
  -v /opt/bonanza/backups:/backup \
  alpine tar czf /backup/storage_$(date +%Y%m%d).tar.gz /data
```

---

## Monitoring and Observability

### Health Checks

See `docs/plans/b2_error-handling.md` for health check implementation details.

**Routes:**
- `/health/liveness` - Is the process running? (for Docker restart)
- `/health/readiness` - Can handle requests? (for load balancer)

**Docker health check:**
```yaml
services:
  rails:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health/liveness"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### Logging

**Structured JSON logging in production:**
```yaml
services:
  rails:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
```

**View logs:**
```bash
# All services
docker compose logs -f

# Specific service with timestamps
docker compose logs -f --timestamps rails

# Last 100 lines
docker compose logs --tail=100 rails
```

### Error Tracking

See `docs/plans/b2_error-handling.md` for Sentry integration.

**Required environment variables:**
```env
SENTRY_DSN=https://xxx@sentry.io/xxx
```

### Resource Monitoring

```bash
# Container resource usage
docker stats

# Disk usage
docker system df

# Cleanup unused images
docker image prune -a
```

### Alerting (Future Enhancement)

Consider adding:
- Uptime monitoring (Uptime Robot, Pingdom)
- Log aggregation (Loki, ELK stack)
- Metrics dashboard (Prometheus + Grafana)

For now, rely on:
- Docker health checks for auto-restart
- Sentry for error alerts
- Manual log review

---

## Open Questions and Decisions Needed

1. **Asset Compilation Strategy**:
   - Compile during image build (slower builds, faster startup)?
   - Compile at runtime (faster builds, slower startup)?
   - Recommendation: Build-time for production, runtime for development

2. **Development Live Reload**:
   - Mount source code as volume?
   - Use separate development Dockerfile?
   - Recommendation: Volume mounts with docker-compose.override.yml

3. **Elasticsearch Synonyms**:
   - Bake into image or mount as volume?
   - Recommendation: Mount as volume for easier updates

4. **Database Migrations**:
   - Automatic on startup or manual step?
   - Recommendation: Automatic for development, manual for production

5. **Platform Target**:
   - Multi-architecture build (ARM64 + AMD64)?
   - Recommendation: Build for both, use `docker buildx`

6. **Bundle Platform**:
   - README mentions `bundle lock --add-platform x86_64-linux`
   - Need to determine if still necessary with Docker

## Success Criteria

- [ ] Can run `docker-compose up` on fresh clone and access working application
- [ ] All services start and pass health checks
- [ ] Database migrations run successfully
- [ ] Elasticsearch indexes are created and searchable
- [ ] Application accessible via Caddy on http://localhost
- [ ] Mailpit UI accessible on http://localhost:8025 and captures emails sent from Rails
- [ ] Asset pipeline produces correct JS and CSS bundles
- [ ] Logs are accessible via `docker-compose logs`
- [ ] Data persists across container restarts
- [ ] Development workflow allows code changes without rebuild
