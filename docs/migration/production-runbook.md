# Production Migration Runbook

# ABOUTME: Step-by-step guide for migrating Bonanza v1 (MySQL) to Redux (PostgreSQL).
# ABOUTME: Based on staging server exploration. Production server may differ — validate before cutover.

## Prerequisites

- Root SSH access to the server
- MySQL credentials (in `/var/www/bonanza/config/database.yml`, cleartext)
- Paperclip hash secret (in `/var/www/bonanza/config/secrets.yml`)
- Redux Docker image built and pushed to registry

## Deployment Layout

| Component | Path |
|-----------|------|
| Redux deployment | `/opt/bonanza/` |
| Docker Compose, Caddyfile, .env | `/opt/bonanza/` |
| Migration scripts (temporary) | `/root/migration/` |

The deployment runs as root during initial setup. After migration is validated,
a dedicated `bonanza` user takes over (see Step 15).

## Server Layout (confirmed on both staging and production)

| Component | Value |
|-----------|-------|
| v1 app directory | `/var/www/bonanza/` |
| v1 Ruby | 2.5 |
| v1 process | puma 4.3.12, port 9292, runs as root |
| MySQL | localhost:3306 (also via socket `/var/run/mysqld/mysqld.sock`) |
| MySQL database | `bonanzasql1` |
| MySQL user | `bonanzasql1` |
| MySQL credentials | Cleartext in `/var/www/bonanza/config/database.yml` |
| Elasticsearch (v1) | 6.4.0 (incompatible with Redux 8.4, reindex only) |
| Paperclip files | `/var/www/bonanza/public/files/` (23 files, 55 MB) |
| Paperclip secret | `config/secrets.yml` under `production.paperclip_hash_secret` |

## v1 Data Summary (production, confirmed)

| Table | Staging | Production | Redux Table | Notes |
|-------|---------|------------|-------------|-------|
| departments | 10 | 11 | departments | Direct copy + defaults |
| users | 28 | 30 | users | Role split to department_memberships |
| lenders | 999 | 1,125 | borrowers | Rename table + fields |
| parent_items | 674 | 700 | parent_items | Drop bundle_id, storage_location |
| items | 871 | 1,080 | items | Rename comment→note, add storage_location |
| lendings | 2,777 | 3,430 | lendings | Rename lender_id→borrower_id |
| line_items | 6,727 | 6,982 | line_items | Direct copy |
| item_histories | 18,498 | 19,156 | item_histories | Rename comment→note |
| accessories | 1,281 | 1,293 | accessories | Direct copy |
| accessories_line_items | 30,457 | 31,298 | accessories_line_items | Direct copy |
| tags | 740 | 745 | tags | Direct copy |
| taggings | 750 | 755 | taggings | Direct copy (tenant=NULL) |
| links | 108 | 108 | links | Direct copy |
| assets | 23 | 23 | (files only) | Paperclip metadata, rsync files |
| conducts | 6 | 6 | conducts | Rename lender_id→borrower_id |

### User Role Distribution (production: 30 users)

| v1 Role | v1 Value | Count | Redux Mapping |
|---------|----------|-------|---------------|
| admin | 3 | 4 | DepartmentMembership role=leader + User.admin=true |
| leader | 2 | 13 | DepartmentMembership role=leader |
| standard | 1 | 11 | DepartmentMembership role=member |
| guest | 0 | 2 | DepartmentMembership role=guest |
| deleted | 99 | 0 | (none) |

### Borrower Type Distribution (production: 1,125 borrowers)

| v1 Type | Value | Count | Redux Mapping |
|---------|-------|-------|---------------|
| student | 0 | 1,049 | borrower_type=student |
| employee | 1 | 70 | borrower_type=employee |
| deleted | 2 | 6 | borrower_type=deleted (anonymize after import) |

### Data Quality (confirmed on both staging and production)

- No NULL values in borrower required fields (email, firstname, lastname, phone)
- No NULL parent_item_id on items
- No NULL borrower_id or department_id on conducts
- No NULL url or parent_item_id on links
- 467 of 700 parent_items have storage_location data (migrate to items)
- All taggings are on ParentItem with context "tags"
- Files: 23 files, 55 MB (identical on staging and production)

### Known Data Issue: Duplicate student_id

Two test borrowers on production share `student_id = '1'`:

| id | name | email | student_id | type |
|----|------|-------|------------|------|
| 1170 | ubaTaeCJ | testing@example.com | 1 | employee |
| 1171 | ubaTaeCJ | testing@example.com | 1 | student |

**Resolution**: NULL out the student_id on both rows before migration, or delete
the test records entirely. These are not real borrowers. Handle in Step 1.5 (below).

## Migration Steps

### Overview

The staging database is small enough that the entire migration takes minutes,
not hours. Production may be larger. The timeline below is conservative.

**Estimated total time: 30-60 minutes** (most of it is verification, not data transfer).

### Step 0: Re-validate Production Data (5 min)

Production was validated during planning. Re-run on cutover day to catch any
changes since then. All queries should return the same structure as the data
summary above (counts may have grown slightly).

```bash
ssh root@PRODUCTION_SERVER
export MYSQL_PWD='<from /var/www/bonanza/config/database.yml>'

# Record counts (compare against table above)
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT table_name, table_rows
  FROM information_schema.tables
  WHERE table_schema = 'bonanzasql1'
  ORDER BY table_rows DESC;
"

# Duplicate student_ids (must return only student_id='1' from known test data,
# or 0 rows if Step 1.5 was already done on an earlier dry run)
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT student_id, COUNT(*) as cnt FROM lenders
  WHERE student_id IS NOT NULL AND student_id != ''
  GROUP BY student_id HAVING COUNT(*) > 1;
"

# NULL checks (all must return 0)
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
```

**If any NULL check returns > 0**: Stop. The transformation script assumes
clean data. Fix the source rows before proceeding.

**If new duplicate student_ids appear** (beyond the known test data): Stop.
Flag for manual review.

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

### Step 1.5: Clean Up Test Data (1 min)

Two test borrowers with duplicate `student_id = '1'` will violate Redux's
unique index. NULL out the student_id before migration.

```bash
mysql -u bonanzasql1 bonanzasql1 -e "
  UPDATE lenders SET student_id = NULL WHERE id IN (1170, 1171);
"

# Verify
mysql -u bonanzasql1 bonanzasql1 -e "
  SELECT student_id, COUNT(*) as cnt FROM lenders
  WHERE student_id IS NOT NULL AND student_id != ''
  GROUP BY student_id HAVING COUNT(*) > 1;
"
# Should return 0 rows
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
# Copy files into the Rails container's public directory
CONTAINER=$(docker compose -f docker-compose.prod.yml ps -q rails)
docker cp /var/www/bonanza/public/files/ "$CONTAINER:/app/public/files/"

# Verify
docker exec "$CONTAINER" ls /app/public/files/ | wc -l  # Should be 23 directories
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

- [ ] Create dedicated `bonanza` user (Step 15)
- [ ] Update TOS and privacy policy content in legal_texts
- [ ] Configure SMTP settings for email delivery
- [ ] Verify Paperclip files are accessible via the web
- [ ] Plan ActiveStorage migration for file attachments
- [ ] Rotate MySQL password (exposed during staging exploration)
- [ ] Rotate Paperclip hash secret (exposed during staging exploration)
- [ ] Keep v1 backup for 30 days minimum
- [ ] Apply OS updates (safe once v1 is stopped and Redux runs in Docker)

### Step 15: Switch to Non-Root User

Running Docker as root works but expands the blast radius of mistakes.
Create a dedicated user to own the deployment:

```bash
# Create user with no login shell (service account)
useradd --system --create-home --shell /usr/sbin/nologin bonanza

# Add to docker group so it can manage containers
usermod -aG docker bonanza

# Transfer ownership of the deployment directory
chown -R bonanza:bonanza /opt/bonanza

# Verify docker access works
su -s /bin/bash bonanza -c "docker ps"
```

After this, manage the stack as the `bonanza` user:

```bash
su -s /bin/bash bonanza
cd /opt/bonanza
docker compose ps
```

Systemd service files or cron jobs should also run as `bonanza`, not root.

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
