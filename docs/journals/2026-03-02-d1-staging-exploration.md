# d1 Server Exploration (Staging + Production)

Phase 0 of the data migration: explored both staging and production servers
with Fabian via SSH to replace assumptions in the migration plan with verified data.

## What We Did

1. **Explored the staging server** via SSH with Fabian
   - Found v1 app at `/var/www/bonanza/`, puma 4.3.12 on port 9292
   - MySQL `bonanzasql1` on localhost:3306, credentials cleartext in `database.yml`
   - Paperclip hash secret in `config/secrets.yml`
   - ES 6.4.0 (incompatible with Redux 8.4, reindex only)
   - 23 Paperclip files, 55 MB
   - Ran record counts, role distribution, borrower types
   - Validated data quality: no duplicate student_ids, no NULLs in required fields
   - Discovered Redux Docker containers already running on staging (stale, from earlier test)

2. **Explored the production server** to validate staging assumptions
   - Identical server layout, same MySQL setup, same ES version, same files
   - Slightly more data (30 users, 1125 borrowers, 1080 items, 3430 lendings)
   - Found one data issue: duplicate `student_id = '1'` on two test borrowers
     (id 1170/1171, `ubaTaeCJ`, `testing@example.com`). Not real borrowers.
   - All NULL checks passed

3. **Created production runbook** (`docs/migration/production-runbook.md`)
   - 14-step guide from backup through go-live
   - Step 0: re-validation queries for cutover day
   - Step 1.5: cleanup of test data (duplicate student_id)
   - Schema mapping reference, rollback procedure
   - All values confirmed against both servers, no credentials committed

4. **Updated migration plan** (`docs/plans/d1_data-migration.md`)
   - Replaced Phase 0 placeholders with confirmed findings
   - Added production record counts alongside staging
   - Corrected wrong assumptions (storage_location IS used — 467/700 on production)
   - Updated resolved questions (7 → 11 items)

5. **Created PR #194** against `beta`

## Production vs Staging

| Item | Staging | Production |
|------|---------|------------|
| departments | 10 | 11 |
| users | 28 (5 admin) | 30 (4 admin) |
| borrowers | 999 | 1,125 |
| parent_items | 674 | 700 |
| items | 871 | 1,080 |
| lendings | 2,777 | 3,430 |
| storage_locations | 433 | 467 |
| files | 23 / 55MB | 23 / 55MB |
| ES version | 6.4.0 | 6.4.0 |
| duplicate student_ids | 0 | 1 (test data) |
| NULL issues | 0 | 0 |

## Assumptions Corrected

1. **storage_location**: Plan said "skipped (not in v1 schema)" — WRONG, 467 parent_items have data on production
2. **Deleted users**: Plan prepared for role=99 — neither server has any
3. **Links**: Plan said "will be added to Redux" — already done, 108 records, clean
4. **ES version**: Was "to be checked" — confirmed 6.4.0 on both
5. **Database size**: Was "5-30 minutes" for pgloader — will take seconds
6. **pgloader config**: The pseudo-code in the plan uses column aliasing that pgloader doesn't support. Real approach TBD.

## Still Open

- How v1 puma is managed (systemd? manual?)
- Caddy/port config for production cutover
- SMTP relay settings
- Preferred cutover weekend
- pgloader vs rake-task-with-mysql2 decision for actual data transfer
- Credential rotation after migration (MySQL pw and Paperclip secret were exposed during exploration)
