# Production Deployment and v1 Migration

## Summary

Deployed Bonanza Redux v2.0.0 to production (bonanza.fh-potsdam.de) and
migrated all v1 data from MySQL to PostgreSQL. The app is live and serving
production traffic.

## Server State Before

- VM: 4 GB RAM (upgraded from 2 GB before session), Ubuntu 22.04 Jammy
- v1 puma was down after the RAM upgrade reboot
- MySQL running with all v1 data intact
- nginx handling TLS with Let's Encrypt, proxying to v1 on port 9292
- Docker not installed
- Host Elasticsearch 6.4.0 running (v1)

## Steps Performed

### Phase 1: Deploy Redux

1. Created `/opt/bonanza/` as deployment directory
2. Downloaded `deploy.sh` from GitHub, ran `./deploy.sh main`
3. Generated secrets (`POSTGRES_PASSWORD`, `ELASTIC_PASSWORD`, `SECRET_KEY_BASE`)
4. Configured `.env` with `APP_HOST=bonanza.fh-potsdam.de`
5. Installed Docker Engine via `get.docker.com` (Phusion Passenger apt repo
   had expired GPG key — warning only, didn't affect install)
6. `docker compose pull && docker compose up -d` — pulled `bonanzahq/bonanza:2.0.0`
7. All 5 containers healthy: db, elasticsearch, rails, worker, caddy
8. Bootstrap created admin user, default department, legal texts

### Phase 2: Migrate v1 Data

1. Transferred migration scripts via `scp` to `/root/migration/`
2. Re-validated production data: counts match, no NULLs, only known duplicate
   student_id on borrowers 1170/1171
3. Ran `00-backup-v1.sh`: MySQL dump (828K gzipped) + Paperclip files (45 MB)
4. Fixed duplicate student_id: `UPDATE lenders SET student_id = NULL WHERE id IN (1170, 1171)`
5. Ran `01-export-v1.sh`: 14 JSONL files, 9.6 MB total
6. Ran `02-run-migration.sh`: all tables loaded, transforms applied
   - Ponderosa department created for 1 orphaned parent_item (dept 13)
   - Setup admin created
   - 1 duplicate conduct deduped
   - 6 deleted borrowers anonymized with GDPR audit logs
7. Validation: 2 expected mismatches (+1 dept, +1 user), all FK checks pass
8. Script exited on validation "failure", had to run reindex manually
9. Reindex: 755 ParentItems, 1129 Borrowers
10. Copied Paperclip files into container (23 directories, 56.7 MB)

### Phase 3: Go Live

1. Replaced nginx config — clean reverse proxy to Caddy on port 8080
   (old config had static asset block pointing to v1 directory, broke CSS)
2. Smoke test passed: login, department switching, search, lendings, timestamps
3. Stopped and disabled v1 services: `systemctl disable puma mysql`

## Data Migrated (actual counts)

| Table | Exported | Loaded | Notes |
|-------|----------|--------|-------|
| departments | 12 | 13 | +1 Ponderosa for orphaned records |
| users | 30 | 31 | +1 setup admin |
| borrowers | 1129 | 1129 | 6 deleted, anonymized |
| parent_items | 755 | 755 | |
| items | 1185 | 1185 | 735 with lending_counter, 790 with storage_location |
| lendings | 3464 | 3464 | |
| line_items | 7504 | 7504 | |
| item_histories | 21107 | 21107 | |
| conducts | 5 | 4 | 1 duplicate deduped |
| accessories | 1399 | 1399 | |
| accessories_line_items | 34085 | 34085 | |
| tags | 789 | 789 | |
| taggings | 786 | 786 | |
| links | 108 | 108 | |

## Issues Found and Fixed

### 1. Docker not installed
Installed via `get.docker.com`. Straightforward.

### 2. nginx static asset block
Old config served `/assets/` and `/packs/` from v1's `/var/www/bonanza/public/`.
Replaced with clean reverse proxy config. Added `docker/nginx-site.conf` to repo.

### 3. /artikel/29 crashes (nil line_item in item history)
`undefined method 'lending' for nil` in `_item_history.html.erb`. An ItemHistory
references a LineItem that doesn't exist (v1 had no FK constraints). Fixed with
nil guards using safe navigation. Filed as GitHub #252, fix included in PR #251.

### 4. Validation script exits on expected mismatches
The +1 department (Ponderosa) and +1 user (setup admin) are expected but the
script treats them as errors and skips the reindex step. Had to run reindex
manually. Could improve the script to distinguish expected from unexpected.

### 5. Paperclip files not persisted across container restarts
Files copied into container would be lost on recreate. Added
`bonanza_public_files` named volume to docker-compose.yml.

## Changes Made

- `scripts/migration/00-backup-v1.sh` — v1 backup script (new)
- `scripts/migration/README.md` — added backup script to file list
- `docker/nginx-site.conf` — production nginx config (new)
- `deploy.sh` — downloads nginx config alongside other files
- `docs/migration/production-runbook.md` — deployment layout, Step 15 non-root
  user, docker cp commands, OS updates in post-migration tasks
- `docker/docker-compose.yml` — added `bonanza_public_files` volume for Rails
- `app/views/parent_items/_item_history.html.erb` — nil guards for orphaned
  line_items
- `test/controllers/parent_items_controller_test.rb` — test for nil line_item
- `docs/plans/d1_data-migration.md` — archived (migration complete)

## Issues Closed

- `299908f` Execute d1: Data migration from v1
- `c259e88` fix: nil guard for orphaned line_item in item history view
- `d6fc456` Epic: Phase D - Cutover

## Post-Migration TODO

- [ ] Create dedicated `bonanza` user (Step 15 in runbook)
- [ ] Update TOS and privacy policy content in legal_texts
- [ ] Configure SMTP settings for email delivery
- [ ] Apply OS updates
- [ ] Keep v1 MySQL backup for 30 days
- [ ] Improve validation script to handle expected +1 counts
- [ ] VPN coordination with FHP IT (d2, human task)
