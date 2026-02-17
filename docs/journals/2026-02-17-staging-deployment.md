# Staging Deployment Session

## What we did

Deployed Bonanza v2 to the FH Potsdam staging server (bonanza2.fh-potsdam.de).

## Key decisions

- **nginx in front of Caddy for TLS**: Caddy's auto-HTTPS doesn't work because
  FHP DNS has AAAA records but the IPv6 firewall blocks inbound traffic.
  Let's Encrypt prefers IPv6 and times out on ACME challenges. Using the
  existing nginx + certbot setup for TLS termination instead.
- **Architecture**: Internet → nginx (TLS 443) → Caddy (HTTP 8080) → Rails (3000)
- **Component-based DB/ES config**: Moved from interpolating passwords into URLs
  in docker-compose.yml to component env vars (DB_HOST, DB_PASSWORD, etc.)
  with URL-encoding in the entrypoint. This handles special characters safely.

## Issues encountered and resolved

1. **CADDY_ADDRESS coupled to APP_HOST** - triggered unwanted ACME. Decoupled.
2. **ADMIN_EMAIL/ADMIN_PASSWORD missing from compose** - bootstrap always failed.
3. **Passwords with special chars** broke URL interpolation in compose.
4. **IPv6 ACME failure** - root cause of Let's Encrypt issues. Nginx workaround.
5. **CSRF InvalidAuthenticityToken** - Rails saw HTTP behind TLS proxy. Fixed
   with `config.assume_ssl = true` (NOT `force_ssl` which causes redirect loops).
6. **docker compose exec can't connect to DB** - exec bypasses entrypoint which
   constructs DATABASE_URL. Fixed by updating database.yml production section
   to use component env vars directly.
7. **Port 80 blocked by FHP firewall** - only 443 is open. Removed port 80 mapping.
8. **Existing cert covers bonanza.fh-potsdam.de not bonanza2** - staging uses
   mismatched cert (browser warning, acceptable for VPN-only staging).

## What's still open

- **Proper TLS cert for bonanza2.fh-potsdam.de** - needs FHP IT to either fix
  IPv6 firewall, remove AAAA record, or provide institutional cert. Bug: 682a427.
- **PR #89** needs merge - database.yml fix and deployment docs.
- **Login not yet verified** - CSRF fix (assume_ssl) was in PR #88 which is merged
  but image may not be deployed yet. Need to pull new image and restart.
- **Credentials exposed in chat** - Fabian needs to rotate passwords and GitHub PAT.

## PRs created this session

- #84 - feat: staging deployment readiness (merged)
- #85 - fix: production deployment robustness (merged)
- #86 - fix: use nginx for TLS (merged)
- #87 - fix: enable force_ssl (closed, replaced by #88)
- #88 - fix: assume_ssl + nginx architecture (merged)
- #89 - fix: database.yml + deployment docs (open)

## Bugs filed

- 682a427 - TLS/HTTPS: Debug and fix Let's Encrypt certificate provisioning (blocked)
- b0590e7 - Upgrade staging server from Ubuntu 22.04 to 24.04
- 5af0461 - Remove Node.js from production Docker image
- 4f8af1b - Switch Docker base image to ruby-slim
