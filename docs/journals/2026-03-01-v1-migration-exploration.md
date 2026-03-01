# V1 Migration Exploration

## Decisions (resolved)

1. **Server hostnames**: Staging and production hostnames known. Not committed to docs for security — use placeholders in commands.
2. **File attachments**: Copy files during migration, wire up ActiveStorage as a separate task later (Option A).
3. **Avatars**: Drop `avatar_data` during migration. Redux will generate its own identicons (filed as git-bug `d683b13`). The current hardcoded placeholder in `_user_menu.html.erb` needs replacing.
4. **Admin users**: Query `SELECT id, email FROM users WHERE role = 3;` on the server during Phase 0. No pre-known list.
5. **Deleted users/borrowers**: Migrate them through Redux's existing GDPR anonymization — "Ehemaliger Mitarbeiter" / "Geloescht Person" pattern. No personal data carried over, no broken foreign keys.
6. **Links table**: v1 `links` is a real feature (URLs for manuals, manufacturer pages, etc., shown on parent item and lending views). Add Link model to Redux before migration. Filed as git-bug `7f45b40`.
7. **Redux deployment model**: Docker on the same bare metal server. Staging Redux already runs on bonanza2. Production Redux will run alongside v1 on different ports, then switch over.

## File Storage Findings

### Paperclip (Asset model)

- **Gem**: paperclip ~> 4.2.0
- **Model**: `Asset` belongs_to `:parent_item` (NOT polymorphic)
- **Association**: `ParentItem` has_many `:assets, dependent: :destroy`
- **Attachment field**: `has_attached_file :file`
- **Path pattern**: `:rails_root/public/files/:hash/:filename`
- **URL pattern**: `http://bonanza.fh-potsdam.de/files/:hash/:filename`
- **Hash secret**: From `Rails.application.secrets.paperclip_hash_secret` (env var `PAPERCLIP_HASH_SECRET` in production)
- **Styles**: Commented out (only originals stored, no thumbnails)
- **Validation**: `do_not_validate_attachment_file_type :file` (accepts any file type)

Files on the server are at `/path/to/bonanza/public/files/` in hash-named subdirectories.

### Avatar Data (User + Lender)

- **NOT Paperclip** — stored directly in the database as a text column
- Generated via `RubyIdenticon.create(...)` with Base64 encoding
- User: seeded from `first_name + last_name + department_id`
- Lender: seeded from `first_name + last_name + email`
- Tiny (~200 byte) auto-generated PNGs, not user uploads
- Safe to drop — can regenerate if ever needed

### No other file storage

- No CarrierWave, no ActiveStorage, no manual file handling in v1
- Redux has `active_storage_*` tables in schema but no models use ActiveStorage yet

## Schema Comparison Findings

### Critical Bug: User Role Enum Mapping

The existing migration plan has the admin role number WRONG in multiple places.

**v1 User.role enum (from app/models/user.rb):**
```ruby
enum role: { guest: 0, standard: 1, leader: 2, admin: 3, deleted: 99 }
```

**Redux DepartmentMembership.role enum:**
```ruby
enum :role, { guest: 0, member: 1, leader: 2, hidden: 3, deleted: 99 }
```

**Correct mapping:**
| v1 role | v1 value | Redux role | Redux value | Notes |
|---------|----------|------------|-------------|-------|
| guest | 0 | guest | 0 | Direct map |
| standard | 1 | member | 1 | Renamed |
| leader | 2 | leader | 2 | Direct map |
| admin | 3 | leader + admin flag | 2 + User.admin=true | Split into role + flag |
| deleted | 99 | ? | 99 | Needs decision |

The plan says "role == 2 (admin in v1)" in multiple places. This is WRONG — role=2 is leader, role=3 is admin. If the migration runs with the current plan, leaders get marked as admin and actual admins don't.

### Undocumented Schema Differences

1. **conducts: lifted_by_id, lifted_at** — New Redux fields for tracking when/who lifted a ban. Not in v1. Should be NULL during migration (existing bans have no lift history).

2. **avatar_data removal** — Plan mentions dropping it but doesn't explain what it is or that it's safe to drop (auto-generated identicons, not user uploads).

3. **New Redux-only tables not acknowledged in plan:**
   - `active_storage_attachments`, `active_storage_blobs`, `active_storage_variant_records` — Rails framework tables
   - `gdpr_audit_logs` — new audit feature
   - `solid_queue_*` (11 tables) — job queue infrastructure
   - These need no v1 data, but should be acknowledged in the plan

4. **Lender type enum matches exactly**: student=0, employee=1, deleted=2 — no mapping issues.

## Server Exploration Strategy

Since v1 runs bare metal (NOT Docker) and Fabian has root SSH access:

### Step 1: Find the app directory

```bash
# Find the Rails app
find / -name "database.yml" -path "*/bonanza/*" 2>/dev/null

# Or check common locations
ls -la /var/www/bonanza/ /home/*/bonanza/ /srv/bonanza/ /opt/bonanza/ 2>/dev/null

# Check running processes for the app path
ps aux | grep -i puma
ps aux | grep -i bonanza
```

### Step 2: Find MySQL credentials

```bash
# Check the running process environment (most reliable)
cat /proc/$(pgrep -f puma | head -1)/environ | tr '\0' '\n' | grep -i bonanza

# Check database.yml for hardcoded values
cat /path/to/bonanza/config/database.yml

# Check for .env or dotenv files
ls -la /path/to/bonanza/.env* 2>/dev/null
cat /path/to/bonanza/.env 2>/dev/null

# Check systemd service file (if managed by systemd)
systemctl list-units | grep -i bonanza
systemctl cat bonanza  # or whatever the service is called

# Check for environment in the service file
grep -r BONANZA /etc/systemd/ 2>/dev/null
grep -r BONANZA /etc/environment /etc/profile.d/ 2>/dev/null

# Check crontab for environment hints
crontab -l
cat /path/to/bonanza/config/schedule.rb
```

### Step 3: Explore the database

```bash
# Set these from what you found in steps 1-2
MYSQL_USER="..."    # from database.yml / process env
MYSQL_DB="..."      # production database name

# Connect to MySQL (try socket first, then TCP)
mysql -u "$MYSQL_USER" -p "$MYSQL_DB"
# Or with socket:
mysql -u "$MYSQL_USER" -p --socket=/var/run/mysqld/mysqld.sock "$MYSQL_DB"

# Record counts
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "
  SELECT table_name, table_rows
  FROM information_schema.tables
  WHERE table_schema = '$MYSQL_DB'
  ORDER BY table_rows DESC;
"

# Database and table sizes
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "
  SELECT table_name,
         ROUND(data_length/1024/1024, 2) AS data_mb,
         ROUND(index_length/1024/1024, 2) AS index_mb
  FROM information_schema.tables
  WHERE table_schema = '$MYSQL_DB'
  ORDER BY data_length DESC;
"

# Check assets table specifically
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "SELECT COUNT(*) FROM assets;"
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "SELECT * FROM assets LIMIT 5;"

# Check user roles distribution
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "SELECT role, COUNT(*) FROM users GROUP BY role;"

# Check links table
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "SELECT COUNT(*) FROM links;"
```

### Step 4: Dump the database

```bash
# Full dump (structure + data), compressed
mysqldump -u "$MYSQL_USER" -p --single-transaction --routines --triggers \
  "$MYSQL_DB" | gzip > bonanza_v1_dump_$(date +%Y%m%d).sql.gz

# Schema only (for comparison)
mysqldump -u "$MYSQL_USER" -p --no-data "$MYSQL_DB" > bonanza_v1_schema.sql

# Sample dump (100 rows per table)
mysqldump -u "$MYSQL_USER" -p --single-transaction --where="1 LIMIT 100" \
  "$MYSQL_DB" > bonanza_v1_sample.sql
```

### Step 5: Find and size Paperclip files

```bash
# Find the public/files directory
find /path/to/bonanza/public/files -type f | head -20
du -sh /path/to/bonanza/public/files/
find /path/to/bonanza/public/files -type f | wc -l

# Check file types
find /path/to/bonanza/public/files -type f -exec file {} \; | head -20
```

### Step 6: Get the Paperclip hash secret

```bash
# From environment
cat /proc/$(pgrep -f puma | head -1)/environ | tr '\0' '\n' | grep PAPERCLIP

# From secrets.yml (production section reads from env var)
cat /path/to/bonanza/config/secrets.yml
```

### Step 7: Copy data off the server

```bash
# From your local machine
scp root@SERVER:/path/to/bonanza_v1_dump_*.sql.gz .
scp root@SERVER:/path/to/bonanza_v1_schema.sql .

# For files (rsync is better for large directories)
rsync -avz root@SERVER:/path/to/bonanza/public/files/ ./v1_files/
```

## File Migration Strategy

### Recommended: Hybrid approach

1. **Dump Asset table** data during MySQL dump (it contains the metadata: file names, content types, sizes, parent_item_id)
2. **rsync files** from `public/files/` on the server
3. **Decide later** whether to wire up ActiveStorage or serve files from the old path
4. **Drop avatar_data** entirely (auto-generated identicons)

This preserves all data without committing to an ActiveStorage migration before Redux models are ready for it. The file migration can be a separate task after the core data migration works.

## Related Issues

- git-bug #76 (file storage)
- git-bug #8 (d1 migration)
