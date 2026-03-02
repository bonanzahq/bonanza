# Staging Server Upgrade Plan: Ubuntu 22.04 → 24.04

## Server Inventory

| Property | Value |
|----------|-------|
| Hostname | bonanza |
| OS | Ubuntu 22.04.4 LTS (jammy) |
| Kernel | 5.15.0-119-generic |
| Architecture | x86-64 |
| Virtualization | KVM (QEMU) — VM snapshots available |
| RAM | 2 GB (swap 2 GB, nearly exhausted) |
| Disk | 30 GB total, 21 GB used (73%), 8.1 GB free |
| Uptime | 335 days at time of investigation |
| Docker | 29.2.1, Compose v5.0.2 |
| MySQL | 8.0.39-0ubuntu0.22.04.1 (Ubuntu package) |

### Running Services

**v1 (bare metal):**

| Service | Details |
|---------|---------|
| puma.service | v1 Rails app, runs as root via `/root/.rbenv/shims/bundle`, WorkingDirectory `/var/www/bonanza` |
| mysql.service | MySQL 8.0.39, database `bonanzasql1`, data at `/var/lib/mysql/` (286 MB) |
| elasticsearch.service | ES 6.4.0, data at `/var/lib/elasticsearch/` (3.3 MB) |
| nginx.service | Reverse proxy for v1 |

**v2 (Docker containers):**

| Container | Image | Ports |
|-----------|-------|-------|
| bonanza-redux-caddy-1 | caddy:2.10.2 | 8080→8080 |
| bonanza-redux-rails-1 | bonanzahq/bonanza:latest | (internal) |
| bonanza-redux-db-1 | postgres:17.7 | 5432 (internal) |
| bonanza-redux-elasticsearch-1 | elasticsearch:8.4.0 | 9200, 9300 (internal) |

**Other:** fail2ban, SSH, containerd, cron, qemu-guest-agent

### Disk Usage Breakdown

| Path | Size | Notes |
|------|------|-------|
| `/var/lib/containerd` | 5.2 GB | Container runtime layers |
| `/var/lib/docker` | 3.5 GB | Docker images/containers/volumes |
| `/var/log/journal` | 2.9 GB | 335 days of systemd journal |
| `/root` | 2.8 GB | rbenv, old Ruby builds, gem cache |
| `/var/www/bonanza` | 767 MB | v1 app directory |
| `/var/lib/apt` | 367 MB | Package cache |
| `/var/lib/mysql` | 286 MB | v1 database |
| `/var/lib/elasticsearch` | 3.3 MB | v1 search (tiny, indices rebuilt on demand) |

### User Accounts

`/home/`: bonanza, pavian, philipp, user

## Upgrade Plan

### Strategy

Direct in-place upgrade using `do-release-upgrade`. The tool is installed and
confirms 24.04.4 LTS is available. The `Prompt=lts` setting in
`/etc/update-manager/release-upgrades` is already correct.

Since this is a KVM VM, a hypervisor-level snapshot before the upgrade gives
a complete rollback path regardless of what goes wrong.

### Disk Space: Must Free Space First

8.1 GB free is tight for `do-release-upgrade`, which downloads new packages and
keeps old ones until the upgrade completes. Target: **13+ GB free** before starting.

| Action | Estimated Savings |
|--------|-------------------|
| `journalctl --vacuum-size=100M` | ~2.8 GB |
| `docker image prune` (unused images) | ~2.1 GB |
| `rm -rf /root/ruby-2.4.10` | 281 MB |
| `rm -rf /root/.gem` | 259 MB |
| `apt-get clean` | ~300 MB |
| `rm -rf /root/.local` (investigate first) | up to 1.7 GB |
| **Total** | **~5.5–7.4 GB** |

After cleanup, expect ~13–15 GB free, which is comfortable for the upgrade.

### Pre-Upgrade Checklist

1. **Take a VM snapshot from the hypervisor.** This is the single most important
   step. If anything goes wrong, revert the snapshot. Fabian needs to coordinate
   this with whoever manages the VM host (FHP IT?).

2. **Free disk space** (see table above). Verify with `df -h` that at least
   13 GB is free.

3. **Stop v2 Docker stack.** This frees ~1 GB RAM and avoids any container
   conflicts during package upgrades.
   ```bash
   cd /path/to/docker-compose && docker compose down
   ```

4. **Stop v1 services.** Avoids data corruption if MySQL or ES are running
   during package replacement.
   ```bash
   systemctl stop puma nginx elasticsearch mysql
   ```

5. **Back up v1 data** (belt and suspenders — snapshot is primary):
   ```bash
   mysqldump -u bonanzasql1 -p --single-transaction bonanzasql1 \
     | gzip > /root/bonanza_v1_pre_upgrade_$(date +%Y%m%d).sql.gz
   ```

6. **Update existing packages first:**
   ```bash
   apt-get update && apt-get dist-upgrade -y
   # also update the upgrade tool itself:
   apt-get install -y update-manager-core
   reboot
   ```
   The update-manager-core package is currently outdated (22.04.20 vs 22.04.22).
   The reboot clears the 335-day uptime and loads any pending kernel updates,
   giving a clean baseline.

### Upgrade Procedure

```bash
# Run from an SSH session. do-release-upgrade starts a backup sshd on port 1022
# in case the main SSH connection drops.
do-release-upgrade
```

The tool is interactive. It will:
1. Disable third-party repositories (Docker's apt repo)
2. Download 24.04 packages (~1-2 GB)
3. Install new packages, replace configs (review prompts carefully)
4. Remove obsolete packages
5. Prompt for reboot

**Config file prompts to watch for:**
- `/etc/nginx/nginx.conf` — keep current if v1 config was customized
- `/etc/mysql/mysql.conf.d/mysqld.cnf` — keep current (preserves v1 settings)
- `/etc/elasticsearch/*` — keep current
- `/etc/fail2ban/*` — keep current
- `/etc/ssh/sshd_config` — keep current (don't lose SSH access)

When in doubt, keep the currently installed version. Changes can be reviewed
and merged after the upgrade.

### Post-Upgrade Verification

After reboot:

```bash
# 1. Confirm OS version
lsb_release -a
# Expected: Ubuntu 24.04.x LTS (noble)

# 2. Check kernel
uname -r
# Expected: 6.8.x or similar

# 3. Verify disk space
df -h

# 4. Re-enable Docker apt repo (disabled by do-release-upgrade)
# Check /etc/apt/sources.list.d/ for disabled Docker repo
# Re-add if needed: https://docs.docker.com/engine/install/ubuntu/

# 5. Start v1 services
systemctl start mysql
systemctl start elasticsearch
systemctl start puma
systemctl start nginx
# Verify v1 works:
curl -s http://localhost:9292 | head -5

# 6. Start v2 Docker stack
cd /path/to/docker-compose && docker compose up -d
# Wait for healthy:
docker compose ps
# Verify v2 works:
curl -s http://localhost:8080 | head -5

# 7. Check all services
systemctl list-units --type=service --state=running
systemctl --failed

# 8. Verify Docker
docker --version
docker compose version
docker ps

# 9. Check logs for errors
journalctl -b --priority=err --no-pager | head -50
```

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Upgrade fails mid-way | Low | High | VM snapshot → revert |
| MySQL config incompatibility | Low | Medium | Keep current config at prompt; MySQL 8.0 is in both 22.04 and 24.04 |
| Docker repo disabled | High (expected) | Low | Re-add Docker apt repo after upgrade |
| nginx config overwritten | Medium | Low | Keep current at prompt; v1 config is simple |
| ES 6.4.0 service breaks | Medium | Low | ES 6.4 is ancient and not in Ubuntu repos — it's likely a manual install. May need reinstall, but v1 ES data is only 3.3 MB (indices rebuild from MySQL) |
| SSH access lost | Very low | High | do-release-upgrade runs backup sshd on port 1022; VM console access as fallback |
| Disk space exhaustion during upgrade | Low (after cleanup) | High | Free space to 13+ GB before starting |
| rbenv/Ruby breaks | Low | Low | rbenv is in /root, not managed by apt. Ruby 2.5 binaries should still work on 24.04 |
| Memory pressure during upgrade | Medium | Medium | Stop Docker + v1 services first to free RAM |

### Things to Decide Before Upgrading

1. **VM snapshot access**: Who can take a snapshot? Is it self-service or does
   FHP IT need to do it? This is a hard prerequisite.

2. **Timing**: The server has low usage. A weekend or evening minimizes risk,
   but given the snapshot safety net, any time works.

3. **v1 future**: After the d1 data migration runs on 24.04, do we keep v1
   services (MySQL, ES 6.4, puma, nginx) installed? Removing them would free
   resources and reduce the attack surface. But we may want MySQL around
   briefly as a rollback reference.

4. **Docker reinstall vs. survive**: Docker 29.2.1 is from Docker's official
   repo (not Ubuntu's snap/apt). The upgrade will disable the Docker repo.
   Docker itself should keep running, but `apt-get upgrade` won't update it
   until the repo is re-added. Verify Docker works before re-adding the repo.

### Estimated Timeline

| Step | Duration |
|------|----------|
| Take VM snapshot | 5 min (depends on hosting) |
| Free disk space | 10 min |
| Stop services | 2 min |
| Backup v1 MySQL | 2 min |
| apt dist-upgrade + reboot | 10 min |
| do-release-upgrade | 20–40 min (interactive) |
| Reboot + verification | 15 min |
| **Total** | **~60–90 min** |
