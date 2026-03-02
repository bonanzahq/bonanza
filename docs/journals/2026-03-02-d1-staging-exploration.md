# d1 Staging Server Exploration

Phase 0 of the data migration: explored the staging server with Fabian via SSH
to replace assumptions in the migration plan with verified data.

## Findings

### Server Layout

- v1 app at `/var/www/bonanza/`, puma 4.3.12 on port 9292, running as root
- Ruby 2.5 with vendored bundles for 2.4, 2.5, 2.6, 3.0 (upgraded over time)
- Redux Docker containers already running on same host (from a previous test deployment, stale — needs rebuild)
- MySQL credentials stored cleartext in `database.yml` (common for that era, but should rotate after migration)
- Paperclip hash secret in `config/secrets.yml`

### Database

- MySQL `bonanzasql1` on localhost:3306 (socket + TCP)
- Small dataset: largest table is accessories_line_items at ~30k rows
- 28 users, 999 borrowers, 674 parent_items, 871 items, 2777 lendings
- User roles: 5 admin, 12 leader, 9 standard, 2 guest, 0 deleted
- Borrower types: 934 student, 60 employee, 5 deleted

### Data Quality (all clean)

- No duplicate student_ids
- No NULL values in Redux-required NOT NULL columns
- No NULL urls or parent_item_ids in links
- No NULL borrower_ids or department_ids in conducts
- 433 of 674 parent_items have storage_location (must redistribute to items)
- All taggings on ParentItem with context "tags", no tenant column in v1

### Files

- 23 Paperclip files, 55 MB total (PDFs + images)
- Perfect 1:1 match between asset records and files on disk
- Avatar data is auto-generated identicons, safe to drop

### Elasticsearch

- v1 runs ES 6.4.0, Redux uses ES 8.4
- Completely incompatible — full reindex, no data migration needed

## Assumptions Corrected

1. **storage_location**: Plan said "skipped (not in v1 schema)" — WRONG, 433 parent_items have data. Updated plan and rake task.
2. **Deleted users**: Plan prepared for role=99 users — staging has none. Simplified.
3. **Links**: Plan said "will be added to Redux" — already done (git-bug 7f45b40 resolved). 108 records, clean data.
4. **ES version**: Was "to be checked" — now confirmed 6.4.0.
5. **Database size**: Was "5-30 minutes" for pgloader — will take seconds. Entire migration under 60 minutes.
6. **pgloader config**: The pseudo-code in the plan uses column aliasing syntax that pgloader doesn't support. Need a real approach: either pgloader to staging tables + SQL transformation, or direct rake task with mysql2 gem.

## Documents Created/Updated

- Created `docs/migration/production-runbook.md` — step-by-step execution guide with real values
- Updated `docs/plans/d1_data-migration.md` — replaced Phase 0 with findings, corrected assumptions

## Still Open

- How v1 puma is managed (systemd? manual?)
- Caddy/port config for production cutover
- SMTP relay settings
- Preferred cutover weekend
- pgloader vs rake-task-with-mysql2 decision for actual data transfer
- Credential rotation after migration
