# Session: Staging Server Upgrade

## What We Did

Investigated the staging server, documented its state, and upgraded it from
Ubuntu 22.04 to 24.04 LTS.

### Investigation

Fabian ran commands on the server (no direct SSH access for Claude). Gathered:

- OS: Ubuntu 22.04.4 LTS, kernel 5.15.0-119, KVM VM on Proxmox
- 2 GB RAM, 30 GB disk (73% used, 8.1 GB free)
- 335 days uptime, swap nearly exhausted

Discovered v1 is still running bare-metal alongside the v2 Docker stack:
- v1: puma (systemd, root, rbenv), MySQL 8.0, ES 6.4.0, nginx
- v2: Rails + worker + PostgreSQL + ES 8.4 + Caddy (all Docker)
- v1 lives at `/var/www/bonanza/`, not `/home/bonanza/`

Disk breakdown showed `/var/lib/containerd` (5.2G), Docker (3.5G), journal
(2.9G), and `/root` (2.8G with old Ruby builds and gem cache) as main consumers.

### Cleanup

Freed ~4 GB: journal vacuum, Docker image prune, old Ruby builds, apt cache.
Disk went from 8.1 GB free to 13 GB free.

### Docker Stack Test

Verified `deploy.sh` and deployment files are in sync across main and beta.
Brought the Docker stack up with the worker service (new since initial staging
deployment). All 5 containers healthy. Image: `bonanzahq/bonanza:2.0.0-beta.2`.

### Upgrade

Fabian coordinated a Proxmox snapshot with FHP IT (Claude has no Proxmox access).

Upgrade steps:
1. Stopped Docker stack and v1 services
2. `apt dist-upgrade` → 22.04.5, kernel 5.15.0-171, rebooted
3. `do-release-upgrade` → 24.04.4, kernel 6.8.0-101
4. Kept nginx.conf and sshd_config, accepted new sudoers and ssh moduli
5. Rebooted

One issue: nginx failed to start because Phusion Passenger module was removed
during the upgrade but config files remained. Removed two files:
- `/etc/nginx/modules-enabled/50-mod-http-passenger.conf`
- `/etc/nginx/conf.d/mod-http-passenger.conf`

Passenger was a leftover — v1 uses puma directly, not passenger.

All services restarted successfully. v1 (puma, mysql, nginx) and v2 (full
Docker stack) both running.

### Documentation

- `docs/structure/staging-server.md` — server reference with services, disk
  management, OS upgrade procedure, and post-migration cleanup plan
- `docs/journals/2026-03-02-staging-upgrade-plan.md` — investigation findings
  and upgrade notes

PR #199 against beta.

## Decisions Made

- Upgrade before migration so d1 runs on 24.04 (same OS as eventual production)
- Keep v1 services running until after migration, then remove them
- Config file prompts: keep local nginx/sshd, accept new sudoers/moduli

## Closed Issues

- `b0590e7` — Upgrade staging server from Ubuntu 22.04 to 24.04 (done)
