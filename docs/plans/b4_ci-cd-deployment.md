# CI/CD and Deployment Strategy

## Goals

- Run tests on GitHub CI for all PRs
- Test Docker build process on PRs
- Semantic versioning and automated releases
- Build and push Docker images to GHCR
- Deploy to two separate servers: **beta** and **production**
- Simple, fault-tolerant deployment (KISS principle)
- Use existing image if registry unavailable
- No orchestration overhead (no Swarm, Kubernetes, Portainer)

## Prerequisites

This plan assumes containerization is complete per `docs/plans/containerization.md`:
- Dockerfile exists and builds successfully
- docker-compose.yml configurations ready for beta and production
- Health check endpoint implemented (`/up`)
- All services properly configured

**Version Management**:
- Project uses `mise` for version management (Ruby, Node.js, pnpm)
- Versions defined in `mise.toml`
- Package manager: pnpm (not yarn or npm)

## Architecture Overview

```
GitHub Repository
  │
  ├─> Pull Request
  │   ├─> Run tests (Minitest)
  │   └─> Test Docker build
  │
  ├─> Push to main branch
  │   ├─> Run tests
  │   ├─> Build Docker image
  │   ├─> Tag as :beta
  │   ├─> Push to GHCR
  │   └─> Deploy to beta server via SSH
  │
  └─> Push git tag (v1.2.3)
      ├─> Run tests
      ├─> Build Docker image
      ├─> Tag as :latest and :v1.2.3
      ├─> Push to GHCR
      ├─> Create GitHub Release
      └─> Deploy to production server via SSH

Beta Server                    Production Server
  └─> /opt/bonanza               └─> /opt/bonanza
      ├─> deploy.sh                  ├─> deploy.sh
      ├─> docker-compose.beta.yml    ├─> docker-compose.prod.yml
      └─> .env                       └─> .env
```

## Release Management

### Strategy: Manual Git Tags

Use simple git tags for versioning (Ruby ecosystem standard):

```bash
# Create release
git tag v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# GitHub Actions automatically:
# 1. Builds Docker image
# 2. Tags as v1.2.3 and latest
# 3. Pushes to GHCR
# 4. Creates GitHub Release with notes
# 5. Deploys to production
```

**Version format**: `vMAJOR.MINOR.PATCH` (e.g., v1.2.3)

### Alternative: semantic-release (Future Enhancement)

If automated versioning is needed later, use semantic-release with conventional commits:
- Uses commit messages to determine version bump
- Generates changelogs automatically
- Creates git tags and GitHub releases

**Recommendation**: Start with manual tags, add automation only if needed.

## GitHub Container Registry (GHCR)

### Image Naming
- Repository: `ghcr.io/bonanzahq/bonanza_redux`
- Beta tag: `ghcr.io/bonanzahq/bonanza_redux:beta`
- Production tags:
  - `ghcr.io/bonanzahq/bonanza_redux:latest`
  - `ghcr.io/bonanzahq/bonanza_redux:v1.2.3`

### Why GHCR over Docker Hub
- Free private repositories
- Seamless GitHub Actions integration
- No separate account/login needed
- 500MB package storage per repo (free tier)
- Automatic cleanup policies available

## GitHub Actions Workflows

### Workflow 1: test.yml - Test on Pull Requests

**Trigger**: Pull requests to main, pushes to main
**Purpose**: Validate code changes before merge

```yaml
name: Test

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: bonanza_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    env:
      RAILS_ENV: test
      DATABASE_URL: postgresql://postgres:postgres@localhost:5432/bonanza_test

    steps:
      - uses: actions/checkout@v4

      - name: Install mise
        uses: jdx/mise-action@v2

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Setup database
        run: bundle exec rails db:schema:load

      - name: Run tests
        run: bundle exec rails test

      - name: Run system tests
        run: bundle exec rails test:system

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Test Docker build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          cache-from: type=gha
          cache-to: type=gha,mode=max
          tags: ghcr.io/${{ github.repository }}:test
```

**Key features**:
- Uses mise to install Ruby, Node.js, and pnpm from `mise.toml`
- Runs PostgreSQL service container for tests
- Tests both unit and system tests
- Validates Docker build without pushing
- Uses GitHub Actions cache for faster builds
- No Elasticsearch needed (disabled via Searchkick test mode)

### Workflow 2: deploy-beta.yml - Beta Deployment

**Trigger**: Push to main branch
**Purpose**: Automatically deploy to beta server

```yaml
name: Deploy Beta

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    # ... same test steps as test.yml ...

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=beta
            type=sha,prefix=beta-

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to beta server
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.BETA_HOST }}
          username: ${{ secrets.BETA_USER }}
          key: ${{ secrets.BETA_SSH_KEY }}
          script: |
            cd /opt/bonanza
            ./deploy/deploy.sh beta
```

**Key features**:
- Tests must pass before building
- Builds and pushes to GHCR with `beta` tag
- Also tags with git SHA for traceability
- SSH into beta server and runs deployment script
- Fails fast if any step fails

### Workflow 3: release.yml - Production Release

**Trigger**: Git tag push (v*.*.*)
**Purpose**: Release to production

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  test:
    runs-on: ubuntu-latest
    # ... same test steps as test.yml ...

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true

  deploy-production:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy to production server
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/bonanza
            ./deploy/deploy.sh production
```

**Key features**:
- Only runs on version tags (v1.2.3)
- Tags image with version, major.minor, and latest
- Creates GitHub Release with auto-generated notes
- Uses GitHub Environment for production (allows manual approval if configured)
- Deploys to production server

## Deployment Script

**Location**: `deploy/deploy.sh` (on each server)

Simple, fault-tolerant script that handles the deployment:

```bash
#!/bin/bash
set -e

ENVIRONMENT=${1:-production}
COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
IMAGE_NAME="ghcr.io/bonanzahq/bonanza_redux"

if [ "$ENVIRONMENT" = "production" ]; then
  IMAGE_TAG="latest"
else
  IMAGE_TAG="beta"
fi

echo "🚀 Deploying Bonanza Redux - ${ENVIRONMENT}"
echo "📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}"

# Pull new image (with fallback to existing)
echo "⬇️  Pulling new image..."
if ! docker pull ${IMAGE_NAME}:${IMAGE_TAG}; then
  echo "⚠️  Failed to pull new image from registry"
  echo "🔄 Continuing with existing image"
fi

# Run migrations
echo "🗄️  Running database migrations..."
docker-compose -f ${COMPOSE_FILE} run --rm app bundle exec rails db:migrate

# Reindex Elasticsearch
echo "🔍 Reindexing Elasticsearch..."
docker-compose -f ${COMPOSE_FILE} run --rm app bundle exec rails runner "
  ParentItem.reindex
  Borrower.reindex
  puts '✅ Reindex complete'
"

# Restart services with zero-downtime (if using multiple replicas)
echo "🔄 Restarting services..."
docker-compose -f ${COMPOSE_FILE} up -d --remove-orphans

# Wait for health check
echo "🏥 Waiting for health check..."
RETRIES=30
until [ "$(docker inspect --format='{{.State.Health.Status}}' $(docker-compose -f ${COMPOSE_FILE} ps -q app))" = "healthy" ] || [ $RETRIES -eq 0 ]; do
  echo "⏳ Waiting for app to be healthy... ($RETRIES retries left)"
  sleep 5
  RETRIES=$((RETRIES-1))
done

if [ $RETRIES -eq 0 ]; then
  echo "❌ Health check failed!"
  echo "🔙 Rolling back..."
  docker-compose -f ${COMPOSE_FILE} logs --tail=50 app
  exit 1
fi

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✅ Deployment complete!"
echo "📊 Service status:"
docker-compose -f ${COMPOSE_FILE} ps
```

**Features**:
- Uses existing image if registry pull fails (fault tolerance)
- Runs migrations automatically
- Reindexes Elasticsearch after deployment
- Waits for health check before declaring success
- Rolls back on health check failure
- Cleans up old images to save disk space

**Make executable**:
```bash
chmod +x deploy/deploy.sh
```

## Server Setup

### Requirements
- Ubuntu 22.04 LTS (or similar)
- Docker 24+ and Docker Compose v2
- At least 4GB RAM (2GB for Elasticsearch, rest for app + services)
- SSH access with key-based authentication
- Firewall allowing ports 22, 80, 443

### Initial Setup (Both Beta and Production)

#### 1. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

#### 2. Setup Application Directory

```bash
# Create app directory
sudo mkdir -p /opt/bonanza
sudo chown $USER:$USER /opt/bonanza
cd /opt/bonanza

# Create deploy directory
mkdir -p deploy
```

#### 3. Copy Configuration Files

Copy from repository to server:
- `docker-compose.prod.yml` (or `docker-compose.beta.yml`)
- `deploy/deploy.sh`
- `deploy/elastic_synonyms.txt` (if not mounted from image)

#### 4. Create Environment File

```bash
# Create .env file with secrets
cat > .env <<EOF
# Database
DB_PASSWORD=$(openssl rand -base64 32)

# Rails
SECRET_KEY_BASE=$(openssl rand -base64 64)
RAILS_MASTER_KEY=<from config/master.key>

# Email (production only)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=user@example.com
SMTP_PASSWORD=<smtp-password>
SMTP_DOMAIN=example.com

# Optional
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=5
EOF

# Secure the file
chmod 600 .env
```

#### 5. Login to GHCR

```bash
# Create GitHub Personal Access Token with read:packages scope
# Then login
echo $GITHUB_TOKEN | docker login ghcr.io -u bonanzahq --password-stdin
```

Store credentials for automatic pulls:
```bash
# Docker will save credentials in ~/.docker/config.json
# Ensure this persists for the deployment user
```

#### 6. Initial Deployment

```bash
# First deployment
./deploy/deploy.sh production

# Setup database (first time only)
docker-compose -f docker-compose.prod.yml run --rm app bundle exec rails db:setup

# Test access
curl http://localhost/up
```

## GitHub Repository Secrets

Add these secrets in GitHub repository settings (Settings → Secrets and variables → Actions):

### Beta Server
- `BETA_HOST`: Beta server hostname/IP
- `BETA_USER`: SSH username (e.g., `deploy`)
- `BETA_SSH_KEY`: Private SSH key (entire key including headers)

### Production Server
- `PROD_HOST`: Production server hostname/IP
- `PROD_USER`: SSH username (e.g., `deploy`)
- `PROD_SSH_KEY`: Private SSH key (entire key including headers)

### SSH Key Setup

```bash
# On your machine, generate deploy key
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/deploy_key

# Copy public key to servers
ssh-copy-id -i ~/.ssh/deploy_key.pub user@beta-server
ssh-copy-id -i ~/.ssh/deploy_key.pub user@prod-server

# Copy private key contents to GitHub secret
cat ~/.ssh/deploy_key
# Paste entire output (including BEGIN/END lines) into BETA_SSH_KEY and PROD_SSH_KEY
```

## Workflow Examples

### Beta Deployment Flow

```bash
# Developer workflow
git checkout main
git pull
git checkout -b feature/new-feature

# Make changes, commit
git add .
git commit -m "feat: add new feature"

# Push and create PR
git push origin feature/new-feature
# Create PR in GitHub

# After PR review and merge to main:
# → GitHub Actions automatically:
#   1. Runs tests
#   2. Builds Docker image with :beta tag
#   3. Pushes to GHCR
#   4. Deploys to beta server

# Test on beta
curl https://beta.bonanza.example.com
```

### Production Release Flow

```bash
# After testing on beta, create release
git checkout main
git pull

# Create and push tag
git tag v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# → GitHub Actions automatically:
#   1. Runs tests
#   2. Builds Docker image with :latest and :v1.2.3 tags
#   3. Pushes to GHCR
#   4. Creates GitHub Release with notes
#   5. Deploys to production server

# Verify production
curl https://bonanza.example.com
```

## Rollback Procedures

### Quick Rollback (Previous Version)

On the server:

```bash
cd /opt/bonanza

# Pull previous version
docker pull ghcr.io/bonanzahq/bonanza_redux:v1.2.2

# Edit docker-compose file to use specific version
# OR set IMAGE_TAG env var
export IMAGE_TAG=v1.2.2

# Restart with previous version
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d

# Check health
docker-compose -f docker-compose.prod.yml ps
curl http://localhost/up
```

### Database Rollback

```bash
# Rollback last migration
docker-compose -f docker-compose.prod.yml run --rm app bundle exec rails db:rollback

# Rollback specific number of migrations
docker-compose -f docker-compose.prod.yml run --rm app bundle exec rails db:rollback STEP=3
```

### Full Rollback via GitHub Actions

```bash
# Delete the bad tag
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3

# Create new tag pointing to previous commit
git tag v1.2.4 <previous-good-commit>
git push origin v1.2.4

# This triggers new release deployment
```

## Monitoring and Logging

### View Logs

```bash
# All services
docker-compose -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.prod.yml logs -f app

# Last 100 lines
docker-compose -f docker-compose.prod.yml logs --tail=100 app

# Follow logs with timestamps
docker-compose -f docker-compose.prod.yml logs -f -t app
```

### Health Checks

```bash
# Check all services status
docker-compose -f docker-compose.prod.yml ps

# Check specific service health
docker inspect --format='{{.State.Health.Status}}' $(docker-compose -f docker-compose.prod.yml ps -q app)

# Manual health check
curl http://localhost/up
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

## Backup Strategy

### Database Backups

Create backup script: `/opt/bonanza/backup/backup.sh`

```bash
#!/bin/bash
BACKUP_DIR="/opt/bonanza/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p $BACKUP_DIR

# Backup database
docker exec $(docker-compose -f /opt/bonanza/docker-compose.prod.yml ps -q db) \
  pg_dump -U bonanza bonanza_production | gzip > $BACKUP_DIR/db_${DATE}.sql.gz

# Remove old backups
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: db_${DATE}.sql.gz"
```

Schedule via cron:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/bonanza/backup/backup.sh >> /var/log/bonanza_backup.log 2>&1
```

### Restore from Backup

```bash
# Restore database
gunzip < /opt/bonanza/backups/db_20241006.sql.gz | \
  docker exec -i $(docker-compose -f docker-compose.prod.yml ps -q db) \
  psql -U bonanza bonanza_production
```

### Volume Backups

```bash
# Backup PostgreSQL volume
docker run --rm \
  -v bonanza_postgres_data:/data \
  -v /opt/bonanza/backups:/backup \
  alpine tar czf /backup/postgres_$(date +%Y%m%d).tar.gz /data

# Backup Elasticsearch volume
docker run --rm \
  -v bonanza_elasticsearch_data:/data \
  -v /opt/bonanza/backups:/backup \
  alpine tar czf /backup/elasticsearch_$(date +%Y%m%d).tar.gz /data
```

## Security Considerations

### Server Hardening

```bash
# Enable UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Disable password authentication
sudo vim /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd

# Auto security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Docker Security

```bash
# Run containers as non-root (already in Dockerfile)
# Use read-only root filesystem where possible
# Limit container resources in docker-compose.yml

# Example resource limits:
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
```

### Secrets Management

- Never commit `.env` files
- Rotate secrets regularly
- Use GitHub Environments with protection rules for production
- Consider HashiCorp Vault for production secrets

### SSL/TLS

Handled by Caddy automatically. See containerization plan for Caddyfile configuration.

## Performance Optimization

### Build Optimization

Current GitHub Actions caching strategy:
- Uses `type=gha` cache for Docker layers
- Bundler cache handled by mise
- pnpm cache handled by mise

Typical build times:
- First build: ~5-10 minutes
- Cached build: ~2-3 minutes

**Known bottleneck:** The Dockerfile's `chown -R rails:rails /app` step
takes ~107s locally because it recurses over all precompiled assets and
copied source files. With Docker layer caching this only runs when the
app code changes, but it will still be the slowest step in CI builds.
Consider mitigating with:
- `COPY --chown=rails:rails` instead of a separate `RUN chown` step
- Or restructuring the multi-stage build to copy files as the rails user

### Deployment Optimization

- Health checks prevent premature completion
- Parallel service startup where possible
- Image pruning prevents disk filling

### Optional: Multiple App Replicas

For higher availability (future enhancement):

```yaml
services:
  app:
    deploy:
      replicas: 2
    # Load balanced by Caddy
```

Requires Docker Swarm mode or Kubernetes (not KISS).

## Cost Considerations

### GHCR Storage

- Free tier: 500MB per package
- Monitor image sizes: `docker images`
- Cleanup old tags regularly via GitHub Actions

### Server Resources

**Minimum per server**:
- 4GB RAM (2GB for Elasticsearch)
- 2 vCPU
- 40GB disk

**Estimated costs** (DigitalOcean/Hetzner):
- Beta server: ~$12-20/month (small instance)
- Production server: ~$24-40/month (medium instance)

### Shared Resources Option

If budget is tight:
- Share Elasticsearch between beta/prod (different indices)
- Or skip Elasticsearch on beta, use pg_search fallback

## Troubleshooting

### Common Issues

**1. Health check fails after deployment**
```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs app

# Common causes:
# - Database migration failed
# - Elasticsearch not ready
# - Missing environment variables
```

**2. Cannot pull image from GHCR**
```bash
# Check authentication
docker login ghcr.io

# Verify image exists
docker manifest inspect ghcr.io/bonanzahq/bonanza_redux:latest

# Script continues with existing image (fault tolerance)
```

**3. SSH deployment fails**
```bash
# Test SSH connection
ssh -i ~/.ssh/deploy_key user@server

# Verify deploy script is executable
ls -la /opt/bonanza/deploy/deploy.sh

# Check server logs
tail -f /var/log/syslog
```

## Implementation Order

### 1. GitHub Actions Setup
- Create `.github/workflows/` directory
- Implement test.yml workflow
- Test PR workflow locally with `act` (optional)
- Implement deploy-beta.yml workflow
- Implement release.yml workflow

### 2. Server Provisioning
- Provision beta server
- Install Docker and dependencies
- Setup SSH keys
- Setup application directories
- Create .env files with secrets

### 3. Beta Deployment
- Add GitHub secrets for beta
- Test manual deployment
- Test automated deployment via GitHub Actions
- Configure backups
- Document any issues

### 4. Production Setup
- Provision production server
- Clone beta setup to production
- Add GitHub secrets for production
- Configure monitoring
- Test production deployment

### 5. Hardening and Documentation
- Implement rollback procedures
- Test disaster recovery
- Create runbook for operations
- Train team on deployment process
- Setup alerting (future)

## Next Steps

1. Review plan with Fabian
2. Ensure containerization plan is complete
3. Create GitHub Actions workflow files
4. Provision beta server
5. Test beta deployment
6. Provision production server
7. Test production release
8. Document procedures for team

## Alternatives Considered

| Solution | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Docker Compose + SSH (chosen)** | Simple, full control, KISS | Manual server management | ✅ Best fit |
| **Kamal** | Rails-native, simple deploys | Newer, less mature | 🤔 Worth considering |
| **Dokku** | Heroku-like PaaS | Extra complexity for one app | ❌ Overkill |
| **Kubernetes** | Enterprise scale | Way too complex | ❌ No |
| **Capistrano** | Traditional Rails deployment | No containerization | ❌ Outdated |

### Note on Kamal

Kamal (https://kamal-deploy.org/) is 37signals' deployment tool built for Rails:
- Similar simplicity to our approach
- Uses Docker + SSH
- Built by Rails core team
- Zero-downtime deployments built-in
- Worth evaluating if you want maintained tooling instead of custom scripts
