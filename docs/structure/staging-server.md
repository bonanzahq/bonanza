# Staging Server

// ABOUTME: Documents the staging server infrastructure, services, and OS upgrade procedure.
// ABOUTME: Reference for server administration and future Ubuntu LTS upgrades.

## Overview

The staging server hosts both Bonanza v1 (bare metal) and v2 (Docker) on the
same machine. v1 remains running until the data migration (plan d1) is complete,
after which its services will be removed.

| Property | Value |
|----------|-------|
| Hostname | bonanza |
| OS | Ubuntu 24.04.4 LTS (noble) |
| Kernel | 6.8.x |
| Virtualization | KVM (QEMU) on Proxmox |
| RAM | 2 GB + 2 GB swap |
| Disk | 30 GB |
| IP (v4) | 194.94.235.206 |
| IP (v6) | 2001:638:81c:1:250:56ff:feac:577e |

## Request Flow

```
Internet → nginx (TLS :443) → Caddy (HTTP :8080) → Rails (:3000)
```

nginx handles TLS termination because Caddy's auto-HTTPS fails on this server.
FH Potsdam DNS has AAAA records but the IPv6 firewall blocks inbound traffic,
so Let's Encrypt ACME challenges time out. See `docs/plans/tls-debugging.md`
for the full investigation.

## Services

### v2 (Docker)

Managed via Docker Compose in `/root/bonanza-redux/`.

| Container | Image | Purpose |
|-----------|-------|---------|
| bonanza-redux-rails-1 | bonanzahq/bonanza:TAG | Rails app (Puma on :3000) |
| bonanza-redux-worker-1 | bonanzahq/bonanza:TAG | Solid Queue background jobs |
| bonanza-redux-db-1 | postgres:17.7 | PostgreSQL database |
| bonanza-redux-elasticsearch-1 | elasticsearch:8.4.0 | Search (xpack security enabled) |
| bonanza-redux-caddy-1 | caddy:2.10.2 | Reverse proxy (:8080) |

Configuration is in `/root/bonanza-redux/.env`. See `example.env` for the
template and `docs/structure/deployment.md` for troubleshooting.

### v1 (bare metal, temporary)

v1 will be removed after the data migration. These services exist only as the
migration source.

| Service | Details |
|---------|---------|
| puma.service | Rails 4.2.9, Ruby 2.6.10 via `/root/.rbenv/`, port 9292 |
| mysql.service | MySQL 8.0, database `bonanzasql1`, data in `/var/lib/mysql/` |
| elasticsearch.service | ES 6.4.0, data in `/var/lib/elasticsearch/` |
| nginx.service | TLS termination, proxies to Caddy :8080 |

v1 app directory: `/var/www/bonanza/`

### Other

| Service | Purpose |
|---------|---------|
| fail2ban | Brute-force protection |
| ssh | Remote access |
| qemu-guest-agent | Proxmox VM management |

## Deployment

See `docs/structure/deployment.md` for full deployment docs.

Quick reference:

```bash
# SSH to server, then:
cd /root/bonanza-redux

# Pull latest image and restart
docker compose pull
docker compose up -d

# Check health
docker compose ps
curl -s http://localhost:8080/health

# View logs
docker compose logs -f rails
```

## Disk Space Management

The server has 30 GB total. With both v1 and v2 running, space is tight.

Major consumers:

| Path | Typical Size | Notes |
|------|-------------|-------|
| `/var/lib/containerd` | ~5 GB | Container runtime layers |
| `/var/lib/docker` | ~3.5 GB | Docker images, containers, volumes |
| `/var/log/journal` | grows ~10 MB/day | Uncapped by default |
| `/root` | ~2.5 GB | rbenv, gem cache, old Ruby builds |
| `/var/www/bonanza` | ~770 MB | v1 app |
| `/var/lib/mysql` | ~290 MB | v1 database |

Routine cleanup:

```bash
# Vacuum systemd journal (keeps 7 days)
journalctl --vacuum-time=7d

# Remove unused Docker images
docker image prune

# Clear apt cache
apt-get clean
```

After the data migration, removing v1 services and `/root/.rbenv`, `/root/.gem`,
`/var/www/bonanza` will free several GB.

## OS Upgrade Procedure

This documents the 22.04 → 24.04 upgrade performed on 2026-03-02. Follow the
same pattern for future LTS upgrades (e.g., 24.04 → 26.04 in 2028).

### Prerequisites

1. **Proxmox snapshot.** Fabian does not have Proxmox access — coordinate with
   FHP IT. This is a hard prerequisite; do not proceed without a snapshot.
2. **At least 10 GB free disk space.** Run cleanup commands above if needed.

### Steps

1. **Stop all services:**
   ```bash
   cd /root/bonanza-redux && docker compose down
   systemctl stop puma nginx elasticsearch mysql
   ```

2. **Update current release fully:**
   ```bash
   apt-get update && apt-get dist-upgrade -y
   apt-get install -y update-manager-core
   reboot
   ```

3. **Run the upgrade:**
   ```bash
   do-release-upgrade
   ```
   The tool is interactive. Config file prompts:
   - `nginx.conf` → keep current (has v1 proxy config)
   - `sshd_config` → keep current (don't risk losing SSH access)
   - `sudoers` → install new (security fixes)
   - `ssh/moduli` → install new (updated DH parameters)

4. **Reboot** when prompted.

5. **Fix any broken services.** The 22.04 → 24.04 upgrade removed the Phusion
   Passenger nginx module but left its config files behind:
   ```bash
   # Only needed if nginx fails to start with passenger errors
   rm /etc/nginx/modules-enabled/50-mod-http-passenger.conf
   rm /etc/nginx/conf.d/mod-http-passenger.conf
   nginx -t
   ```

6. **Restart services:**
   ```bash
   systemctl start mysql nginx
   cd /root/bonanza-redux && docker compose up -d
   ```

7. **Verify:**
   ```bash
   lsb_release -a
   docker compose ps
   systemctl status mysql nginx puma --no-pager
   curl -s http://localhost:8080/health
   ```

### Post-Upgrade

- Re-add Docker apt repository if it was disabled by the upgrade tool.
  Check `/etc/apt/sources.list.d/` for disabled files.
- Apply any pending security updates: `apt-get update && apt-get upgrade -y`
- Notify FHP IT that the snapshot can be removed once stability is confirmed.

## Post-Migration Cleanup

After the v1 → v2 data migration is complete and verified:

1. Stop and disable v1 services:
   ```bash
   systemctl stop puma mysql elasticsearch
   systemctl disable puma mysql elasticsearch
   ```

2. Remove v1 packages:
   ```bash
   apt-get purge mysql-server mysql-client elasticsearch
   apt-get autoremove --purge
   ```

3. Remove v1 files:
   ```bash
   rm -rf /var/www/bonanza
   rm -rf /root/.rbenv /root/.gem /root/ruby-*
   ```

4. Evaluate whether nginx is still needed. If Caddy can handle TLS directly
   (IPv6 firewall fixed or AAAA record removed), nginx can be replaced entirely.

5. Keep the MySQL backup from the migration for at least 30 days.
