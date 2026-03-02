# Production Migration Runbook

# ABOUTME: Step-by-step guide for migrating Bonanza v1 (MySQL) to Redux (PostgreSQL).
# ABOUTME: Based on staging server exploration. Production server may differ — validate before cutover.

## Prerequisites

- Root SSH access to the server
- MySQL credentials (in `/var/www/bonanza/config/database.yml`, cleartext)
- Paperclip hash secret (in `/var/www/bonanza/config/secrets.yml`)
- Redux Docker image built and pushed to registry

## Server Layout (from staging — validate on production)

Values below were gathered from the staging server. The production server likely
has the same layout but may differ in record counts, file counts, credentials,
ports, or process management. Run the validation script (Step 0) on production
before proceeding.

| Component | Staging Value | Validate on Production |
|-----------|---------------|----------------------|
| v1 app directory | `/var/www/bonanza/` | Confirm path |
| v1 Ruby | 2.5 | Confirm version |
| v1 process | puma 4.3.12, port 9292, runs as root | Confirm port + process manager |
| MySQL | localhost:3306 (also via socket) | Confirm access method |
| MySQL database | `bonanzasql1` | Confirm name |
| MySQL user | `bonanzasql1` | Confirm user |
| Elasticsearch (v1) | 6.4.0 | Confirm version |
| Paperclip files | `/var/www/bonanza/public/files/` | Confirm path + count |
| Paperclip secret | `config/secrets.yml` | Confirm location |

## v1 Data Summary (staging — re-run on production)

Record counts from **staging**. Production will have different (likely higher)
counts. Re-run the validation queries on production before cutover.

| Table | Rows | Redux Table | Notes |
|-------|------|-------------|-------|
| departments | 10 | departments | Direct copy + defaults |
| users | 28 | users | Role split to department_memberships |
| lenders | 999 | borrowers | Rename table + fields |
| parent_items | 674 | parent_items | Drop bundle_id, storage_location |
| items | 871 | items | Rename comment→note, add storage_location |
| lendings | 2,777 | lendings | Rename lender_id→borrower_id |
| line_items | 6,727 | line_items | Direct copy |
| item_histories | 18,498 | item_histories | Rename comment→note |
| accessories | 1,281 | accessories | Direct copy |
| accessories_line_items | 30,457 | accessories_line_items | Direct copy |
| tags | 740 | tags | Direct copy |
| taggings | 750 | taggings | Direct copy (tenant=NULL) |
| links | 108 | links | Direct copy |
| assets | 23 | (files only) | Paperclip metadata, rsync files |
| conducts | 6 | conducts | Rename lender_id→borrower_id |

### User Role Distribution (28 users)

| v1 Role | v1 Value | Count | Redux Mapping |
|---------|----------|-------|---------------|
| admin | 3 | 5 | DepartmentMembership role=leader + User.admin=true |
| leader | 2 | 12 | DepartmentMembership role=leader |
| standard | 1 | 9 | DepartmentMembership role=member |
| guest | 0 | 2 | DepartmentMembership role=guest |
| deleted | 99 | 0 | (none in staging) |

### Borrower Type Distribution (999 borrowers)

| v1 Type | Value | Count | Redux Mapping |
|---------|-------|-------|---------------|
| student | 0 | 934 | borrower_type=student |
| employee | 1 | 60 | borrower_type=employee |
| deleted | 2 | 5 | borrower_type=deleted (anonymize after import) |

### Data Quality (verified clean on staging — re-validate on production)

These were clean on staging. Production may have different data. Run the
validation queries in Step 0 on production before cutover.

- No duplicate student_ids
- No NULL values in borrower required fields (email, firstname, lastname, phone)
- No NULL parent_item_id on items
- No NULL borrower_id or department_id on conducts
- No NULL url or parent_item_id on links
- 433 of 674 parent_items have storage_location data (migrate to items)
- All taggings are on ParentItem with context "tags"

## Migration Steps

### Overview

The staging database is small enough that the entire migration takes minutes,
not hours. Production may be larger. The timeline below is conservative.

**Estimated total time: 30-60 minutes** (most of it is verification, not data transfer).

### Step 0: Validate Production Server (10 min)

Run these queries on the production server to confirm assumptions from staging
still hold. Compare output against the staging values above. If anything differs
significantly (especially data quality checks), stop and assess before proceeding.

```bash
ssh root@PRODUCTION_SERVER

# Confirm app location and process
ls /var/www/bonanza/config/database.yml
ps aux | grep -i puma

# Confirm MySQL access (set MYSQL_PWD from database.yml)
export MYSQL_PWD='<from database.yml>'
mysql -u bonanzasql1 bonanzasql1 -e "SELECT 1;"

# Record counts
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT table_name, table_rows
  FROM information_schema.tables
  WHERE table_schema = 'bonanzasql1'
  ORDER BY table_rows DESC;
"

# Role distribution
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT role, COUNT(*) as cnt FROM users GROUP BY role;
  SELECT type, COUNT(*) as cnt FROM lenders GROUP BY type;
"

# Data quality: duplicate student_ids (must return 0 rows)
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT student_id, COUNT(*) as cnt FROM lenders
  WHERE student_id IS NOT NULL AND student_id != ''
  GROUP BY student_id HAVING COUNT(*) > 1;
"

# Data quality: NULL checks on Redux NOT NULL columns (all must return 0)
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT COUNT(*) as null_email FROM lenders WHERE email IS NULL OR email = '';
  SELECT COUNT(*) as null_firstname FROM lenders WHERE first_name IS NULL OR first_name = '';
  SELECT COUNT(*) as null_lastname FROM lenders WHERE last_name IS NULL OR last_name = '';
  SELECT COUNT(*) as null_phone FROM lenders WHERE phone IS NULL OR phone = '';
  SELECT COUNT(*) as null_parent_item FROM items WHERE parent_item_id IS NULL;
  SELECT COUNT(*) as null_link_url FROM links WHERE url IS NULL OR url = '';
  SELECT COUNT(*) as null_link_parent FROM links WHERE parent_item_id IS NULL;
  SELECT COUNT(*) as null_conduct_borrower FROM conducts WHERE lender_id IS NULL;
  SELECT COUNT(*) as null_conduct_dept FROM conducts WHERE department_id IS NULL;
"

# File count and size
du -sh /var/www/bonanza/public/files/
find /var/www/bonanza/public/files -type f | wc -l

# Elasticsearch version
curl -s localhost:9200 | grep number

# Confirm Paperclip secret exists
grep paperclip_hash_secret /var/www/bonanza/config/secrets.yml | wc -l
```

**If any NULL check returns > 0**: The migration transformation script needs
a strategy for those rows (default values, skip, or manual fix). Do not proceed
until resolved.

**If duplicate student_ids exist**: Must deduplicate before migration. Flag
duplicates for manual review — do not auto-resolve.

### Step 1: Backup v1 (5 min)

```bash
ssh root@SERVER

# Set credentials (get from /var/www/bonanza/config/database.yml)
export MYSQL_PWD='<password from database.yml>'

# Full MySQL backup
mysqldump -u bonanzasql1 --single-transaction bonanzasql1 \
  | gzip > /root/bonanza_v1_backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Backup Paperclip files
tar czf /root/bonanza_v1_files_$(date +%Y%m%d_%H%M%S).tar.gz \
  /var/www/bonanza/public/files/

# Verify backups
ls -lh /root/bonanza_v1_*
```

### Step 2: Stop v1 (1 min)

```bash
# Find and stop v1 puma
# Check how v1 is managed first:
systemctl list-units | grep -i bonanza
# If systemd:
systemctl stop bonanza
# If not managed by systemd, kill directly:
kill $(pgrep -f 'puma.*bonanza')

# Verify v1 is stopped
curl -s http://localhost:9292 && echo "STILL RUNNING" || echo "STOPPED"
```

### Step 3: Export v1 Role Data (1 min)

The v1 `users.role` column maps to a different enum in Redux. Export before
migration so we can map roles correctly afterward.

```bash
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT id, role FROM users;
" > /tmp/v1_user_roles.tsv
```

### Step 4: Export v1 Storage Locations (1 min)

v1 stores `storage_location` on `parent_items`. Redux stores it on `items`.
Export the mapping so the transformation script can redistribute it.

```bash
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT id, storage_location FROM parent_items
  WHERE storage_location IS NOT NULL AND storage_location != '';
" > /tmp/v1_storage_locations.tsv
```

### Step 5: Prepare Redux Containers (5 min)

```bash
# If stale containers exist, remove them
docker compose -f docker-compose.prod.yml down -v

# Pull/build fresh image
docker compose -f docker-compose.prod.yml pull
# OR build locally:
docker compose -f docker-compose.prod.yml build

# Start containers (Caddy on port 8080 while testing, v1 is stopped anyway)
docker compose -f docker-compose.prod.yml up -d

# Wait for PostgreSQL and ES to be healthy
docker compose -f docker-compose.prod.yml ps
# Repeat until db and elasticsearch show "healthy"

# Load Redux schema
docker compose -f docker-compose.prod.yml exec -T rails \
  bundle exec rails db:schema:load RAILS_ENV=production
```

### Step 6: Install pgloader (if not already installed)

```bash
apt-get update && apt-get install -y pgloader
```

### Step 7: Run pgloader (2 min)

pgloader transfers raw data from MySQL to PostgreSQL. Column renames and
transformations happen in the next step.

Copy the pgloader config to the server, then run:

```bash
# The config file references MySQL and PostgreSQL connection details.
# Adjust credentials in the file before running.
pgloader /path/to/bonanza_migration.load 2>&1 | tee /tmp/pgloader.log

# Check for errors
grep -iE 'error|warning' /tmp/pgloader.log
```

**What pgloader does:**
- Copies all v1 tables into temporary staging tables in PostgreSQL
- Handles MySQL→PostgreSQL type conversion (tinyint→boolean, datetime→timestamp)
- Does NOT rename columns or tables — that's the transformation step

**What pgloader does NOT do:**
- Column renames (first_name→firstname, etc.)
- Table renames (lenders→borrowers)
- Role mapping, storage_location redistribution
- Creating department_memberships or legal_texts

### Step 8: Run Data Transformation (2 min)

The rake task reads from pgloader's staging tables and inserts into Redux tables
with correct column names, types, and derived data.

```bash
# Copy the exported role and storage_location data into the container
docker cp /tmp/v1_user_roles.tsv $(docker compose -f docker-compose.prod.yml ps -q rails):/app/tmp/
docker cp /tmp/v1_storage_locations.tsv $(docker compose -f docker-compose.prod.yml ps -q rails):/app/tmp/

# Run the transformation
docker compose -f docker-compose.prod.yml exec -T rails \
  bundle exec rails migrate:transform_v1 RAILS_ENV=production
```

**What the transformation does:**
1. Maps `lenders` → `borrowers` with renamed columns
2. Maps `users` with renamed columns, sets `admin` flag from role data
3. Creates `department_memberships` from v1 role + department data
4. Maps `lendings` and `conducts` (lender_id → borrower_id)
5. Maps `items` and `item_histories` (comment → note)
6. Copies storage_location from parent_items to items
7. Calculates lending_counter for each item
8. Sets borrowers.tos_accepted_at from created_at where tos_accepted is true
9. Sets department defaults (hidden=false, genus=0)
10. Creates default legal_texts
11. Copies links (direct, schema matches)
12. Copies tags, taggings (adds NULL tenant column)
13. Copies direct-transfer tables (departments, parent_items, line_items, accessories, accessories_line_items)
14. Anonymizes deleted borrowers (type=2) using Redux GDPR pattern
15. Resets PostgreSQL sequences to max(id)+1

### Step 9: Copy Paperclip Files (1 min)

```bash
# Copy files into a location accessible by Caddy/Rails
# The exact destination depends on how file serving is configured
cp -r /var/www/bonanza/public/files/ /path/to/redux/public/files/

# Verify
ls /path/to/redux/public/files/ | wc -l  # Should be 23 directories
```

File serving via ActiveStorage is a separate post-migration task. For now,
files are served from the copied directory path via Caddy.

### Step 10: Reindex Elasticsearch (2 min)

v1 uses ES 6.4.0, Redux uses ES 8.4. Indexes are incompatible — full reindex.

```bash
docker compose -f docker-compose.prod.yml exec -T rails \
  bundle exec rails runner "
    puts 'Reindexing ParentItems...'
    ParentItem.reindex
    puts \"ParentItems: #{ParentItem.search_index.total_docs} docs\"

    puts 'Reindexing Borrowers...'
    Borrower.reindex
    puts \"Borrowers: #{Borrower.search_index.total_docs} docs\"
  " RAILS_ENV=production
```

### Step 11: Validate (5 min)

```bash
docker compose -f docker-compose.prod.yml exec -T rails \
  bundle exec rails migrate:validate RAILS_ENV=production
```

**Validation checks:**
- Record counts match v1 (departments, users, borrowers, items, etc.)
- No orphaned foreign keys (items→parent_items, lendings→borrowers, etc.)
- All users have exactly one department_membership
- 5 users have admin=true
- 5 borrowers are anonymized (deleted type)
- Lending states are valid enum values
- Item statuses are valid enum values
- Elasticsearch indexes populated (ParentItem count, Borrower count)

### Step 12: Smoke Test (5 min)

- [ ] Access Redux at the configured port
- [ ] Login as an admin user
- [ ] Login as a leader user
- [ ] Switch departments
- [ ] Search for a parent item by name
- [ ] Search for a borrower by name
- [ ] View a lending with line items
- [ ] View an item's history
- [ ] View a parent item's links
- [ ] Create a test lending, then delete it
- [ ] Verify timestamps look correct (not shifted timezone)

### Step 13: Switch to Production Port (2 min)

```bash
# Update Caddy/docker-compose to serve on the production port
# Edit docker-compose.prod.yml: change Caddy port to match v1's external port

docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# Verify
curl -s http://localhost/up
```

### Step 14: Post-Migration Tasks

These are not blockers for go-live but should be done soon after:

- [ ] Update TOS and privacy policy content in legal_texts
- [ ] Configure SMTP settings for email delivery
- [ ] Verify Paperclip files are accessible via the web
- [ ] Plan ActiveStorage migration for file attachments
- [ ] Rotate MySQL password (exposed during staging exploration)
- [ ] Rotate Paperclip hash secret (exposed during staging exploration)
- [ ] Keep v1 backup for 30 days minimum

## Rollback

Since v1 data doesn't change after Step 2 (v1 stopped), rollback is straightforward:

```bash
# 1. Stop Redux
docker compose -f docker-compose.prod.yml down

# 2. Restart v1
systemctl start bonanza  # or: cd /var/www/bonanza && bundle exec puma ...

# 3. Verify v1 is running
curl -s http://localhost:9292/
```

No data is lost — v1's MySQL database is untouched by the migration.
The backup from Step 1 is an additional safety net.

If issues are found after go-live but within the first few hours (before users
create new data in Redux), the same rollback applies. After users have created
data in Redux, prefer fixing forward.

## Schema Mapping Reference

### Column Renames

| v1 Table | v1 Column | Redux Table | Redux Column |
|----------|-----------|-------------|--------------|
| lenders | first_name | borrowers | firstname |
| lenders | last_name | borrowers | lastname |
| lenders | type | borrowers | borrower_type |
| lenders | tos_token | borrowers | email_token |
| users | first_name | users | firstname |
| users | last_name | users | lastname |
| users | department_id | users | current_department_id |
| items | comment | items | note |
| item_histories | comment | item_histories | note |
| lendings | lender_id | lendings | borrower_id |
| conducts | lender_id | conducts | borrower_id |

### Dropped Columns

| v1 Table | Column | Reason |
|----------|--------|--------|
| users | role | Split into department_memberships + admin flag |
| users | provider, uid, refresh_token, expires_at, access_token | OAuth removed |
| users | avatar_data | Auto-generated identicon, safe to drop |
| lenders | avatar_data | Auto-generated identicon, safe to drop |
| parent_items | bundle_id | Bundles feature removed |
| parent_items | storage_location | Redistributed to items table |

### Derived Data

| Redux Table | Column | Source |
|-------------|--------|--------|
| users | admin | true if v1 role=3, false otherwise |
| department_memberships | role | v1 users.role mapped: 0→guest, 1→member, 2→leader, 3→leader |
| department_memberships | department_id | v1 users.department_id |
| borrowers | tos_accepted_at | v1 lenders.created_at where tos_accepted=true |
| items | storage_location | v1 parent_items.storage_location (same for all items of that parent) |
| items | lending_counter | COUNT of line_items per item |
| departments | hidden | false (default) |
| departments | genus | 0 (default) |

### New Tables (no v1 data)

| Redux Table | Notes |
|-------------|-------|
| department_memberships | Created from v1 user role + department data |
| legal_texts | Created with placeholder content |
| gdpr_audit_logs | Empty |
| active_storage_* (3 tables) | Empty (ActiveStorage wired up later) |
| solid_queue_* (11 tables) | Empty (job queue infrastructure) |
