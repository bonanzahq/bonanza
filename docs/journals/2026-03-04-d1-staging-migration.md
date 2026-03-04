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

**Files changed:**
- `config/initializers/elasticsearch.rb` — constructs URL without credentials,
  passes auth via `Searchkick.client_options`
- `docker-entrypoint.sh` — removed credentials from `ELASTICSEARCH_URL`,
  added `-u` flag to curl ES healthcheck

### 3. Stale ES indices

Failed reindex attempts left orphaned indices (`parent_items_production_*`).
Searchkick tried to create an index that already existed. Fixed by listing
exact index names and deleting them before reindex. Added this to `reindex.rb`.

### 4. Orphaned parent_item (department_id -> missing department)

parent_item 791 references department_id=13, which doesn't exist. v1 MySQL
had no FK constraints, so a department could be deleted without cascading.

**Fixes:**
- `app/models/parent_item.rb`: `department&.id` safe navigation in `search_data`
- `scripts/migration/migrate_v1.rake`: after loading data, scans parent_items,
  lendings, conducts for department_ids not in the departments table. If found,
  creates a hidden "Migration" department and reassigns orphans to it.
- Added `parent_items -> departments` FK check to validation step.

### 5. Phase 0 count discrepancy (non-issue)

The export counts differed from Phase 0 planning counts. Cause: Phase 0 used
`information_schema.tables.table_rows` which is an InnoDB estimate, not exact.
The export uses actual SELECT counts. Staging is not actively used.

### 6. Duplicate conduct safeguards (non-issue)

v1 had a duplicate active ban (borrower 824, dept 11, 2 seconds apart — likely
double-click). Redux has both a model validation and a partial unique index
preventing this. The rake task deduplicates during import. No bug needed.

## Key Lesson

When a correctly-constructed URL still produces auth errors, read the HTTP
client library source to trace how credentials flow from URL to request header.
The bug was in the transport layer, not in our encoding.

## What's Left for Production

1. Build new Docker image with the initializer and entrypoint fixes
2. On production: NULL duplicate `student_id='1'` on borrowers 1170/1171 before export
3. Run `01-export-v1.sh` on production
4. Run `02-run-migration.sh` (now includes patched files and reindex script)
5. Smoke test
6. The "Migration" department will catch any orphaned records automatically

## Files Changed This Session

- `config/initializers/elasticsearch.rb` — ES auth via client_options
- `docker-entrypoint.sh` — remove credentials from ES URL, fix curl auth
- `app/models/parent_item.rb` — nil guard in search_data
- `scripts/migration/02-run-migration.sh` — compose file default, patch files
  into container, use reindex.rb script
- `scripts/migration/migrate_v1.rake` — migration net department, FK validation
- `scripts/migration/reindex.rb` — standalone reindex with stale index cleanup
