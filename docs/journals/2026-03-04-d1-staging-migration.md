# D1 Staging Migration Session

## What Happened

Ran the full v1 data migration on the staging server (bonanza2.fh-potsdam.de).
Data export was already done in a prior session. This session focused on running
the import, fixing issues encountered on the real server, and getting ES reindex
working.

## Results

- **Data load**: All 14 tables imported successfully (64,690 total rows)
- **Validation**: All counts match, FK integrity OK, 28/28 users confirmed
- **ES reindex**: 688 ParentItems + 999 Borrowers indexed
- **Orphan found**: parent_item 791 references department 13 which doesn't exist
  in v1 (deleted department, no FK constraints in MySQL)
- **Setup admin**: Created from ADMIN_EMAIL/ADMIN_PASSWORD in Ponderosa department
- **PR #202**: Created, rebased on beta, reviewed, Copilot feedback addressed

## Issues Found and Fixed

### 1. Compose file name (trivial)

Script defaulted to `docker-compose.prod.yml`, staging uses `docker-compose.yml`.
Changed the default.

### 2. elastic-transport double-encoding bug (root cause of 401 errors)

**Spent most of the session on this.** Every `docker compose exec` command that
tried to talk to Elasticsearch got a 401 Unauthorized.

**Root cause:** elastic-transport 8.4.1's `__full_url` method (base.rb:246)
applies `CGI.escape` to `host[:password]`, but the password was already
percent-encoded by `URI.parse`. So `%40` became `%2540` and `%2A` became
`%252A` — double-encoding. ES received garbage credentials.

**Why it was hard to find:**
- The running Rails server appeared healthy, so we assumed ES connectivity worked.
  But the container healthcheck only tests `/health`, not ES. The entrypoint's
  curl healthcheck for ES works because curl handles URL credentials correctly
  (decodes before sending). The Ruby client doesn't.
- We tried many encoding approaches (python3, ruby URI methods, reading from
  /proc/1/environ) before reading the actual gem source.
- The entrypoint constructs `ELASTICSEARCH_URL` with encoded credentials in the
  URL, which has the same double-encoding bug — the running server's ES
  connection was never actually working either.

**Fix:** Pass `user` and `password` as separate Searchkick `client_options`
instead of embedding them in the URL. elastic-transport then applies `CGI.escape`
to the raw password — single encoding, correct.

**Key lesson:** When a correctly-constructed URL still produces auth errors, read
the HTTP client library source to trace how credentials flow from URL to request
header. The bug was in the transport layer, not in our encoding.

**Files changed:**
- `config/initializers/elasticsearch.rb` — constructs URL without credentials,
  passes auth via `Searchkick.client_options`
- `docker-entrypoint.sh` — removed credentials from `ELASTICSEARCH_URL`,
  added `-u` flag to curl ES healthcheck

### 3. Stale ES indices

Failed reindex attempts left orphaned indices (`parent_items_production_*`).
Searchkick tried to create an index that already existed. Fixed by listing
exact index names and deleting them before reindex. Added this to `reindex.rb`.
Scoped deletion to `Searchkick::Index.name` prefix per Copilot review.

### 4. Orphaned parent_item (department_id -> missing department)

parent_item 791 references department_id=13, which doesn't exist. v1 MySQL
had no FK constraints, so a department could be deleted without cascading.

**Fixes:**
- `app/models/parent_item.rb`: `department&.id` safe navigation in `search_data`
- `scripts/migration/migrate_v1.rake`: after loading data, scans parent_items,
  lendings, conducts for department_ids not in the departments table. If found,
  creates a hidden "Ponderosa" department and reassigns orphans to it.
- Added `parent_items -> departments` FK check to validation step.

### 5. Setup admin wiped by migration

The migration truncates all tables, so the bootstrap admin from
ADMIN_EMAIL/ADMIN_PASSWORD was lost. Fixed: the rake task now creates the setup
admin in the Ponderosa department after loading v1 data.

### 6. Phase 0 count discrepancy (non-issue)

The export counts differed from Phase 0 planning counts. Cause: Phase 0 used
`information_schema.tables.table_rows` which is an InnoDB estimate, not exact.
The export uses actual SELECT counts. Staging is not actively used.

### 7. Duplicate conduct safeguards (non-issue)

v1 had a duplicate active ban (borrower 824, dept 11, 2 seconds apart — likely
double-click). Redux has both a model validation and a partial unique index
preventing this. The rake task deduplicates during import. No bug needed.

## PR Review

Rebased on beta (35 commits had landed since branch point, causing false
"deletions" in the diff). After rebase: 14 files changed, all migration-related.
657 tests pass.

Copilot review feedback addressed:
- Scoped ES index deletion to Searchkick prefix (not bare `parent_items_*`)
- Fixed `RAILS_ENV` position in reindex.rb usage comment
- Fixed `scp` path in README, added `reindex.rb` to file list
- Added `require "set"` for `Set` usage in rake task
- Aligned "Ponderosa" naming across code and docs

## What's Left for Production

1. Merge PR #202 to beta
2. Build new Docker image with ES auth fix + entrypoint changes
3. On production: NULL duplicate `student_id='1'` on borrowers 1170/1171
4. Run `01-export-v1.sh` on production
5. Run `02-run-migration.sh` (creates Ponderosa, setup admin, reindexes)
6. Smoke test
7. Update `IMAGE_TAG` in `.env`, re-run `deploy.sh`

## Files Changed This Session

- `config/initializers/elasticsearch.rb` — ES auth via client_options
- `docker-entrypoint.sh` — remove credentials from ES URL, fix curl auth
- `app/models/parent_item.rb` — nil guard in search_data
- `scripts/migration/02-run-migration.sh` — compose file default, patch files
  into container, use reindex.rb script
- `scripts/migration/migrate_v1.rake` — Ponderosa department, FK validation,
  setup admin creation, `require "set"`
- `scripts/migration/reindex.rb` — standalone reindex with scoped index cleanup
- `scripts/migration/README.md` — fixed scp path, added reindex.rb to file list
- `docs/journals/2026-03-04-d1-staging-migration.md` — this file
