# Data Migration Plan

## Objective

Migrate all data from Bonanza v1 (MySQL + Elasticsearch on bare metal) to Bonanza Redux (PostgreSQL + Elasticsearch in containers) with zero data loss and minimal downtime.

## Current State

### Bonanza v1 (Source)
- **Database**: MySQL (bare metal)
- **Search**: Elasticsearch (bare metal, version to be checked during Phase 0)
- **Hosting**: Bare metal server (no Docker — the Docker files in the v1 repo were never deployed to staging or production)
- **Schema Version**: ActiveRecord 20151110175705

### Bonanza Redux (Target)
- **Database**: PostgreSQL 15 (containerized)
- **Search**: Elasticsearch 8.4 (containerized)
- **Hosting**: Docker containers on same host
- **Schema Version**: ActiveRecord 20230403060517

## Migration Approach

Since both systems will run on the **same host**, we can use a **zero-downtime parallel migration**:

1. Set up Redux containers on different ports (e.g., 3001 instead of 3000)
2. Migrate and test data while v1 remains active
3. When ready, stop v1 and switch Redux to production ports
4. Minimal actual downtime (minutes, not hours)

## Schema Changes Analysis

### Tables Renamed

| v1 Table | Redux Table | Migration Action |
|----------|-------------|------------------|
| `lenders` | `borrowers` | Rename table, adjust field names |

### Fields Renamed

| Table | v1 Field | Redux Field |
|-------|----------|-------------|
| borrowers | `first_name` | `firstname` |
| borrowers | `last_name` | `lastname` |
| borrowers | `type` (enum) | `borrower_type` (enum) |
| borrowers | `tos_token` | `email_token` |
| items | `comment` | `note` |
| item_histories | `comment` | `note` |
| users | `first_name` | `firstname` |
| users | `last_name` | `lastname` |
| parent_items | No field | `storage_location` moved to items table |

### New Tables in Redux

| Table | Purpose | Migration Strategy |
|-------|---------|-------------------|
| `legal_texts` | TOS and privacy policy versions | Create default entries after migration |
| `department_memberships` | User roles per department | Transform from v1 user.role + user.department_id |
| `active_storage_*` (3 tables) | File attachment framework | Empty, no v1 data |
| `gdpr_audit_logs` | GDPR audit trail | Empty, no v1 data |
| `solid_queue_*` (11 tables) | Background job queue | Empty, no v1 data |

### Removed Tables from v1

| Table | Reason | Migration Strategy |
|-------|--------|-------------------|
| `assets` | Replaced by ActiveStorage | Migrate files to ActiveStorage, convert Paperclip metadata |
| `links` | URLs for parent items (manuals, manufacturer pages) | Add Link model to Redux before migration (git-bug 7f45b40), then migrate data |

### Fields Added in Redux

| Table | Field | Default Value |
|-------|-------|---------------|
| departments | `hidden` | `false` |
| departments | `genus` | `0` (neutral) |
| borrowers | `tos_accepted_at` | Copy from `created_at` if `tos_accepted` is true |
| items | `lending_counter` | Calculate from line_items history |
| conducts | Missing `borrower_id` FK | Already references lender in v1 |

### Fields Removed from Redux

| Table | Field | Notes |
|-------|-------|-------|
| users | `role` | Moved to department_memberships |
| users | `department_id` | Renamed to `current_department_id` |
| users | `provider`, `uid`, `refresh_token`, `expires_at`, `access_token` | OAuth removed |
| users | `avatar_data` | Auto-generated identicon (RubyIdenticon), safe to drop |
| borrowers | `avatar_data` | Auto-generated identicon (RubyIdenticon), safe to drop |
| parent_items | `bundle_id` | Bundles feature removed |
| parent_items | `storage_location` | Moved to items table |

## Detailed Schema Mapping

### 1. departments (No schema changes, new fields)
```ruby
# Direct copy with additions:
- hidden: false (default)
- genus: 0 (default, neutral gender)
```

### 2. lenders → borrowers
```ruby
# Field mapping:
first_name → firstname
last_name → lastname
type → borrower_type
tos_token → email_token
tos_accepted → tos_accepted (no change)
tos_accepted_at: NEW (copy created_at if tos_accepted is true)
id_checked → id_checked
insurance_checked → insurance_checked
email → email
phone → phone
student_id → student_id
created_at → created_at
updated_at → updated_at

# Fields to drop:
- avatar_data (auto-generated identicon, safe to drop)

# Constraint: student_id unique index
# v2 has a partial unique index on student_id (WHERE student_id IS NOT NULL).
# The data migration must detect and resolve duplicate student_ids in v1 data
# before inserting into v2. Strategy: flag duplicates for manual review.
# Query v1 for duplicates before migration, export list, resolve manually.
```

### 3. users (Major changes: roles → department_memberships)
```ruby
# Field mapping:
first_name → firstname
last_name → lastname
email → email
encrypted_password → encrypted_password
reset_password_token → reset_password_token
reset_password_sent_at → reset_password_sent_at
remember_created_at → remember_created_at
invitation_token → invitation_token
invitation_created_at → invitation_created_at
invitation_sent_at → invitation_sent_at
invitation_accepted_at → invitation_accepted_at
invitation_limit → invitation_limit
invited_by_id → invited_by_id
invited_by_type → invited_by_type
invitations_count → invitations_count
department_id → current_department_id
created_at → created_at
updated_at → updated_at

# admin field: NEW
# v1 enum: guest=0, standard=1, leader=2, admin=3, deleted=99
# Check if user.role == 3 (admin in v1) → set admin: true
# v1 'standard' maps to Redux 'member'

# Fields to drop:
- role (migrated to department_memberships)
- provider, uid, refresh_token, expires_at, access_token (OAuth removed)
- avatar_data (auto-generated identicon, safe to drop)

# Post-migration: Create department_memberships
# For each user:
#   - Create DepartmentMembership with:
#       user_id: user.id
#       department_id: user.current_department_id
#       role: map from v1 role enum to Redux role enum
```

### 4. parent_items (storage_location moved to items)
```ruby
# Field mapping:
name → name
description → description
department_id → department_id
price → price
created_at → created_at
updated_at → updated_at

# Fields to drop:
- storage_location (moved to items table in Redux)
- bundle_id (bundles feature removed)
```

### 5. items
```ruby
# Field mapping:
uid → uid
quantity → quantity
parent_item_id → parent_item_id
status → status
condition → condition
comment → note (RENAMED)
created_at → created_at
updated_at → updated_at

# New fields:
- storage_location: copy from parent_item.storage_location
- lending_counter: calculate from line_items count
```

### 6. item_histories
```ruby
# Field mapping:
quantity → quantity
comment → note (RENAMED)
condition → condition
status → status
item_id → item_id
user_id → user_id
line_item_id → line_item_id
created_at → created_at
updated_at → updated_at
```

### 7. lendings (conducts foreign key fix)
```ruby
# Direct copy, no changes
lender_id → borrower_id (FK references borrowers table now)
```

### 8. conducts (lender_id → borrower_id, new fields)
```ruby
# Field mapping:
kind → kind
lender_id → borrower_id (RENAMED to match borrowers table)
user_id → user_id
department_id → department_id
lending_id → lending_id
reason → reason
duration → duration
permanent → permanent
created_at → created_at
updated_at → updated_at

# New Redux fields (no v1 equivalent):
# lifted_by_id: NULL (no lift history in v1)
# lifted_at: NULL (no lift history in v1)
```

### 9. line_items (no changes)
```ruby
# Direct copy
```

### 10. accessories (no changes)
```ruby
# Direct copy - now uses `text` type instead of `string` for name
```

### 11. accessories_line_items (no changes)
```ruby
# Direct copy
```

### 12. taggings, tags (acts-as-taggable-on, minor updates)
```ruby
# Redux uses newer version of acts-as-taggable-on
# Add tenant field if missing
# Tags table: id changed from serial to bigint
```

## Migration Tool: pgloader

pgloader automatically handles:
- MySQL → PostgreSQL type conversions
- Character encoding
- Sequences and auto-increment → serial
- Foreign keys
- Indexes

## Migration Phases

### Phase 0: Server Access & Exploration

v1 runs bare metal (NOT Docker). Fabian has root SSH access.

```bash
# Set these after discovering credentials in steps 0.1-0.2
MYSQL_USER="..."          # MySQL username from database.yml / process env
MYSQL_DB="..."            # Production database name
```

#### 0.1 Find the v1 app directory
```bash
ssh root@SERVER
find / -name "database.yml" -path "*/bonanza/*" 2>/dev/null
ps aux | grep -i puma
```

#### 0.2 Find MySQL credentials
```bash
# From the running process environment
cat /proc/$(pgrep -f puma | head -1)/environ | tr '\0' '\n' | grep -iE 'bonanza|mysql|database'

# From the app config
cat /path/to/bonanza/config/database.yml
cat /path/to/bonanza/.env 2>/dev/null

# From systemd (if managed)
systemctl list-units | grep -i bonanza
systemctl cat bonanza
```

#### 0.3 Explore the database
```bash
mysql -u "$MYSQL_USER" -p "$MYSQL_DB"

# Record counts
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = '$MYSQL_DB'
ORDER BY table_rows DESC;

# User role distribution (verify enum values)
SELECT role, COUNT(*) FROM users GROUP BY role;

# Assets count
SELECT COUNT(*) FROM assets;
```

#### 0.4 Find and size Paperclip files
```bash
du -sh /path/to/bonanza/public/files/
find /path/to/bonanza/public/files -type f | wc -l
```

#### 0.5 Get the Paperclip hash secret
```bash
cat /proc/$(pgrep -f puma | head -1)/environ | tr '\0' '\n' | grep PAPERCLIP
```

### Phase 1: Preparation (Week 1)

#### 1.1 Setup Migration Environment
```bash
# Install pgloader locally
brew install pgloader  # macOS
# OR
apt-get install pgloader  # Ubuntu

# Verify SSH access to v1 production (root access available)
ssh root@v1-server
# Connect to MySQL (credentials found in Phase 0)
mysql -u "$MYSQL_USER" -p "$MYSQL_DB"
# Test read access
```

#### 1.2 Document v1 Database
```bash
# Export v1 schema
mysqldump --no-data -u "$MYSQL_USER" -p "$MYSQL_DB" > docs/migration/v1_schema.sql

# Export sample data for testing
mysqldump -u "$MYSQL_USER" -p --single-transaction \
  --where="1 LIMIT 100" \
  "$MYSQL_DB" departments users lenders > docs/migration/v1_sample.sql

# Document record counts
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "
  SELECT 'departments' as table_name, COUNT(*) as count FROM departments
  UNION SELECT 'users', COUNT(*) FROM users
  UNION SELECT 'lenders', COUNT(*) FROM lenders
  UNION SELECT 'parent_items', COUNT(*) FROM parent_items
  UNION SELECT 'items', COUNT(*) FROM items
  UNION SELECT 'lendings', COUNT(*) FROM lendings
  UNION SELECT 'line_items', COUNT(*) FROM line_items
  UNION SELECT 'item_histories', COUNT(*) FROM item_histories
  UNION SELECT 'conducts', COUNT(*) FROM conducts
  UNION SELECT 'accessories', COUNT(*) FROM accessories;
" > docs/migration/v1_counts.txt
```

#### 1.3 Setup Redux on Different Port
```bash
# Edit docker-compose.prod.yml
# Change port mapping from 80:80 to 8080:80 (or similar)
# This allows v1 to continue running on port 80

# Start Redux containers
docker-compose -f docker-compose.prod.yml up -d

# Create database
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails db:create RAILS_ENV=production

# Load schema (don't run migrations, use schema.rb for speed)
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails db:schema:load RAILS_ENV=production
```

### Phase 2: Test Migration (Week 1-2)

#### 2.1 Create pgloader Configuration

**File**: `docs/migration/bonanza_migration.load`

```lisp
LOAD DATABASE
  FROM mysql://bonanza:PASSWORD@v1-server:3306/bonanza
  INTO postgresql://bonanza:PASSWORD@localhost:5432/bonanza_redux_production

WITH
  include drop,
  create no tables,  -- We already loaded schema via Rails
  create no indexes, -- We already have indexes from schema
  reset sequences,   -- Important: fix auto-increment IDs
  workers = 4,
  concurrency = 1

SET PostgreSQL PARAMETERS
  maintenance_work_mem to '512MB',
  work_mem to '128MB'

SET MySQL PARAMETERS
  net_read_timeout = '300',
  net_write_timeout = '300'

-- Type casting
CAST
  type tinyint to boolean drop typemod using tinyint-to-boolean,
  type datetime to timestamptz

-- Rename lenders table to borrowers
BEFORE LOAD DO
$$
  -- Temporarily disable triggers for faster loading
  ALTER TABLE borrowers DISABLE TRIGGER ALL;
  ALTER TABLE lendings DISABLE TRIGGER ALL;
  ALTER TABLE conducts DISABLE TRIGGER ALL;
  ALTER TABLE users DISABLE TRIGGER ALL;
  ALTER TABLE items DISABLE TRIGGER ALL;
  ALTER TABLE item_histories DISABLE TRIGGER ALL;
$$

-- Load data with table rename
LOAD TABLE lenders
  INTO borrowers (
    id, first_name AS firstname, last_name AS lastname,
    student_id, email, phone, tos_token AS email_token,
    tos_accepted, id_checked, insurance_checked,
    type AS borrower_type,
    created_at, updated_at
  )

-- Update borrowers with tos_accepted_at
AFTER LOAD DO
$$
  UPDATE borrowers
  SET tos_accepted_at = created_at
  WHERE tos_accepted = true AND tos_accepted_at IS NULL;
$$

-- Load users
LOAD TABLE users
  INTO users (
    id, first_name AS firstname, last_name AS lastname,
    email, encrypted_password, reset_password_token,
    reset_password_sent_at, remember_created_at,
    department_id AS current_department_id,
    invitation_token, invitation_created_at,
    invitation_sent_at, invitation_accepted_at,
    invitation_limit, invited_by_id, invited_by_type,
    invitations_count, created_at, updated_at
  )
  WITH skip default values

-- Load items with renamed fields
LOAD TABLE items
  INTO items (
    id, uid, quantity, parent_item_id,
    status, condition, comment AS note,
    created_at, updated_at
  )

-- Load item_histories with renamed fields
LOAD TABLE item_histories
  INTO item_histories (
    id, quantity, comment AS note,
    condition, status, item_id, user_id,
    line_item_id, created_at, updated_at
  )

-- Load conducts with lender_id → borrower_id
LOAD TABLE conducts
  INTO conducts (
    id, kind, lender_id AS borrower_id,
    user_id, department_id, lending_id,
    reason, duration, permanent,
    created_at, updated_at
  )

-- Load lendings with lender_id → borrower_id
LOAD TABLE lendings
  INTO lendings (
    id, note, lender_id AS borrower_id,
    lent_at, state, token, user_id,
    returned_at, duration, department_id,
    notification_counter, created_at, updated_at
  )

-- All other tables load as-is
LOAD TABLE departments, parent_items, line_items,
     accessories, accessories_line_items,
     tags, taggings

-- Skip assets table (links table now migrated to Redux)
EXCLUDING TABLE NAMES MATCHING 'assets'

-- Re-enable triggers and fix sequences
AFTER LOAD DO
$$
  -- Re-enable all triggers
  ALTER TABLE borrowers ENABLE TRIGGER ALL;
  ALTER TABLE lendings ENABLE TRIGGER ALL;
  ALTER TABLE conducts ENABLE TRIGGER ALL;
  ALTER TABLE users ENABLE TRIGGER ALL;
  ALTER TABLE items ENABLE TRIGGER ALL;
  ALTER TABLE item_histories ENABLE TRIGGER ALL;

  -- Set admin flag for users with role=3
  -- (This will be done in Rails migration script)

  -- Fix sequences to continue from max ID
  SELECT setval('borrowers_id_seq', COALESCE((SELECT MAX(id) FROM borrowers), 1));
  SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 1));
  SELECT setval('departments_id_seq', COALESCE((SELECT MAX(id) FROM departments), 1));
  SELECT setval('parent_items_id_seq', COALESCE((SELECT MAX(id) FROM parent_items), 1));
  SELECT setval('items_id_seq', COALESCE((SELECT MAX(id) FROM items), 1));
  SELECT setval('lendings_id_seq', COALESCE((SELECT MAX(id) FROM lendings), 1));
  SELECT setval('line_items_id_seq', COALESCE((SELECT MAX(id) FROM line_items), 1));
  SELECT setval('item_histories_id_seq', COALESCE((SELECT MAX(id) FROM item_histories), 1));
  SELECT setval('conducts_id_seq', COALESCE((SELECT MAX(id) FROM conducts), 1));
  SELECT setval('accessories_id_seq', COALESCE((SELECT MAX(id) FROM accessories), 1));
  SELECT setval('tags_id_seq', COALESCE((SELECT MAX(id) FROM tags), 1));
  SELECT setval('taggings_id_seq', COALESCE((SELECT MAX(id) FROM taggings), 1));
$$
;
```

#### 2.2 Run Test Migration
```bash
# Run pgloader (takes 5-30 minutes depending on data size)
pgloader docs/migration/bonanza_migration.load 2>&1 | tee docs/migration/migration.log

# Check for errors
grep -i error docs/migration/migration.log
```

#### 2.3 Create Data Transformation Script

**File**: `lib/tasks/migrate_v1_data.rake`

```ruby
namespace :migrate do
  desc "Transform v1 data to Redux format"
  task transform_v1_data: :environment do
    puts "=== Starting v1 to Redux data transformation ==="

    # 1. Set admin flag for users
    transform_user_admin_flag

    # 2. Create department_memberships from v1 user roles
    create_department_memberships

    # 3. Calculate lending_counter for items
    calculate_item_lending_counters

    # 4. Add storage_location to items from parent_items
    migrate_storage_locations

    # 5. Add default departments fields
    add_department_defaults

    # 6. Create default legal texts
    create_default_legal_texts

    # 7. Validate data
    validate_migration

    puts "=== Transformation complete ==="
  end

  def transform_user_admin_flag
    puts "\n1. Setting admin flag for users..."

    # In v1, role enum was:
    # 0 = guest
    # 1 = standard (maps to Redux 'member')
    # 2 = leader
    # 3 = admin
    # 99 = deleted

    # v1 role=3 means admin. These users get admin=true in Redux.
    # The role integer 3 maps to 'hidden' in Redux's enum, so we must
    # set admin=true AND assign a real department role (leader).
    # This is handled by import_v1_roles which reads the v1 role dump.
    User.where("id IN (SELECT id FROM v1_user_roles WHERE role = 3)")
        .update_all(admin: true)
    puts "   Set admin=true for v1 admin users (role=3)"
  end

  def create_department_memberships
    puts "\n2. Creating department_memberships from v1 user data..."

    # In v1:
    # user.role + user.current_department_id
    #
    # In Redux:
    # DepartmentMembership.create(user: user, department: dept, role: role)

    # We need v1 role data which wasn't migrated
    # Options:
    # A. Store v1 role data in a temp table before migration
    # B. Create memberships with default 'member' role
    # C. Export v1 user roles to CSV and import

    puts "   Creating department memberships..."

    User.find_each do |user|
      next unless user.current_department_id

      # Check if membership already exists
      next if DepartmentMembership.exists?(
        user_id: user.id,
        department_id: user.current_department_id
      )

      # Create with default 'member' role
      # Admin users will need to update roles manually
      DepartmentMembership.create!(
        user_id: user.id,
        department_id: user.current_department_id,
        role: :member  # Default to member, admins update later
      )

      print "."
    end

    puts "\n   Created #{DepartmentMembership.count} department memberships"
  end

  def calculate_item_lending_counters
    puts "\n3. Calculating lending_counter for items..."

    Item.find_each do |item|
      count = LineItem.where(item_id: item.id).count
      item.update_column(:lending_counter, count)
      print "."
    end

    puts "\n   Updated #{Item.count} items"
  end

  def migrate_storage_locations
    puts "\n4. Migrating storage_location from parent_items to items..."

    # In v1: parent_items.storage_location
    # In Redux: items.storage_location

    # We need to query v1 database for this
    # OR if storage_location wasn't used much, skip it

    puts "   ⚠️  storage_location migration skipped (not in v1 parent_items schema)"
    puts "   If this field was used, export it from v1 and import separately"
  end

  def add_department_defaults
    puts "\n5. Adding default values to departments..."

    Department.where(hidden: nil).update_all(hidden: false)
    Department.where(genus: nil).update_all(genus: 0)

    puts "   Updated #{Department.count} departments"
  end

  def create_default_legal_texts
    puts "\n6. Creating default legal texts..."

    if LegalText.none?
      # Find first admin user or create system user
      user = User.where(admin: true).first || User.first

      if user
        LegalText.create!(
          kind: :tos,
          content: "# Ausleihbedingungen\n\nBitte aktualisieren Sie die Ausleihbedingungen.",
          user: user
        )

        LegalText.create!(
          kind: :privacy_policy,
          content: "# Datenschutz\n\nBitte aktualisieren Sie die Datenschutzerklärung.",
          user: user
        )

        puts "   Created default legal texts"
      else
        puts "   ⚠️  No users found, skipping legal texts creation"
      end
    else
      puts "   Legal texts already exist, skipping"
    end
  end

  def validate_migration
    puts "\n7. Validating migration..."

    errors = []

    # Check record counts match (if we have v1 counts)
    counts_file = Rails.root.join('docs/migration/v1_counts.txt')
    if File.exist?(counts_file)
      # Parse and compare counts
      # This is optional and depends on having the counts file
    end

    # Check foreign keys
    orphaned_items = Item.where.not(parent_item_id: ParentItem.select(:id))
    if orphaned_items.any?
      errors << "Found #{orphaned_items.count} orphaned items"
    end

    orphaned_lendings = Lending.where.not(borrower_id: Borrower.select(:id))
    if orphaned_lendings.any?
      errors << "Found #{orphaned_lendings.count} orphaned lendings"
    end

    # Check users have department memberships
    users_without_memberships = User.left_joins(:department_memberships)
      .where(department_memberships: { id: nil })
      .count

    if users_without_memberships > 0
      errors << "Found #{users_without_memberships} users without department memberships"
    end

    if errors.any?
      puts "\n   ❌ Validation errors:"
      errors.each { |e| puts "      - #{e}" }
      exit 1
    else
      puts "   ✅ Validation passed"
    end
  end
end
```

#### 2.4 Run Transformation
```bash
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails migrate:transform_v1_data RAILS_ENV=production
```

### Phase 3: Manual Data Fixes (Week 2)

#### 3.1 Export v1 User Roles
Since pgloader can't include the `role` field in the user query, we need to handle this separately:

```bash
# On v1 server, export user roles
mysql -u "$MYSQL_USER" -p "$MYSQL_DB" -e "
  SELECT id, role FROM users;
" > /tmp/v1_user_roles.csv

# Copy to migration host
scp root@v1-server:/tmp/v1_user_roles.csv docs/migration/
```

#### 3.2 Import User Roles and Create Memberships

**File**: `lib/tasks/import_v1_roles.rake`

```ruby
namespace :migrate do
  desc "Import v1 user roles and create department memberships"
  task import_v1_roles: :environment do
    require 'csv'

    # v1 role enum:
    # 0 = guest
    # 1 = standard (maps to Redux 'member')
    # 2 = leader
    # 3 = admin (gets leader role + User.admin = true)
    # 99 = deleted

    # Redux DepartmentMembership role enum:
    # 0 = guest
    # 1 = member
    # 2 = leader
    # 3 = hidden
    # 99 = deleted

    role_mapping = {
      0 => :guest,
      1 => :member,
      2 => :leader,
      3 => :leader,  # admin gets leader role; admin flag set separately
      99 => :deleted
    }

    CSV.foreach('docs/migration/v1_user_roles.csv', headers: false) do |row|
      user_id = row[0].to_i
      v1_role = row[1].to_i

      user = User.find_by(id: user_id)
      next unless user&.current_department_id

      # Delete existing membership (from default creation)
      DepartmentMembership.where(
        user_id: user.id,
        department_id: user.current_department_id
      ).delete_all

      # Create with correct role
      DepartmentMembership.create!(
        user_id: user.id,
        department_id: user.current_department_id,
        role: role_mapping[v1_role]
      )

      # Set admin flag for users who had role=3 in v1
      if v1_role == 3
        user.update_column(:admin, true)
        puts "User #{user.email}: leader + ADMIN"
      else
        puts "User #{user.email}: #{role_mapping[v1_role]}"
      end
    end
  end
end
```

```bash
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails migrate:import_v1_roles RAILS_ENV=production
```

#### 3.3 Verify Admin Users

Admin users (v1 role=3) are now set automatically in the import_v1_roles task
above. Verify the result:

```bash
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails runner "
    User.where(admin: true).each { |u| puts \"#{u.id}: #{u.email}\" }
  " RAILS_ENV=production
```

#### 3.4 Anonymize Deleted Records

v1 records with `role=99` (deleted users) or `type=2` (deleted borrowers) are
migrated but then anonymized using Redux's existing GDPR anonymization pattern.
This preserves referential integrity while removing personal data.

```bash
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails runner "
    # Anonymize deleted borrowers
    Borrower.where(borrower_type: :deleted).find_each do |b|
      next if b.anonymized?
      b.anonymize!
      print '.'
    end
    puts

    # Anonymize deleted users (role=99 already mapped to deleted membership)
    User.joins(:department_memberships)
      .where(department_memberships: { role: :deleted })
      .distinct.find_each do |u|
      next if u.anonymized?
      u.anonymize!
      print '.'
    end
    puts
  " RAILS_ENV=production
```

### Phase 4: Elasticsearch Reindex (Week 2)

```bash
# Apply ES index template
docker-compose -f docker-compose.prod.yml exec elasticsearch \
  curl -XPUT "http://localhost:9200/_template/default_template" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["*"],
    "settings": {
      "index": {
        "number_of_replicas": 0,
        "number_of_shards": 1
      }
    }
  }'

# Copy synonyms file
docker cp elastic_synonyms.txt \
  $(docker-compose -f docker-compose.prod.yml ps -q elasticsearch):/usr/share/elasticsearch/config/

# Reindex all models
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails runner "
    puts 'Reindexing ParentItems...'
    ParentItem.reindex

    puts 'Reindexing Borrowers...'
    Borrower.reindex

    puts 'Done!'
  " RAILS_ENV=production

# Verify indexes
docker-compose -f docker-compose.prod.yml exec elasticsearch \
  curl http://localhost:9200/_cat/indices?v
```

### Phase 5: Validation & Testing (Week 2)

#### 5.1 Automated Validation
```bash
# Run validation rake task
docker-compose -f docker-compose.prod.yml exec app \
  bundle exec rails migrate:transform_v1_data RAILS_ENV=production
```

#### 5.2 Manual Testing Checklist
- [ ] Login with various user accounts (admin, leader, member, guest)
- [ ] Switch departments
- [ ] Search for parent items
- [ ] Search for borrowers
- [ ] Create a test lending
- [ ] Complete a test lending
- [ ] Return a test lending
- [ ] View lending history
- [ ] View item history
- [ ] Edit borrower
- [ ] Edit item
- [ ] Check all department data visible
- [ ] Verify email addresses are correct
- [ ] Check timestamps are preserved

### Phase 6: Production Cutover (Weekend)

#### Timeline: 2-4 hours total

**Friday Evening** (Optional prep):
```bash
# Do a final test migration with latest v1 data
# This ensures migration scripts are working
```

**Saturday Morning**:

1. **T-0: Put v1 in Maintenance Mode** (10 min)
   ```bash
   # On v1 server, display maintenance page
   # Method depends on v1 deployment
   ```

2. **T+10: Final v1 Backup** (15 min)
   ```bash
   # Full MySQL backup
   mysqldump -u "$MYSQL_USER" -p --single-transaction "$MYSQL_DB" | gzip > bonanza_final_$(date +%Y%m%d_%H%M%S).sql.gz

   # Backup Elasticsearch (if snapshot configured)
   # Backup Paperclip files
   tar czf files_$(date +%Y%m%d_%H%M%S).tar.gz /path/to/bonanza/public/files/
   ```

3. **T+25: Run Production Migration** (30-60 min)
   ```bash
   # Drop and recreate Redux database
   docker-compose -f docker-compose.prod.yml exec app \
     bundle exec rails db:drop db:create db:schema:load RAILS_ENV=production

   # Run pgloader
   pgloader docs/migration/bonanza_migration.load

   # Run transformations
   docker-compose -f docker-compose.prod.yml exec app \
     bundle exec rails migrate:transform_v1_data RAILS_ENV=production

   # Import user roles
   docker-compose -f docker-compose.prod.yml exec app \
     bundle exec rails migrate:import_v1_roles RAILS_ENV=production

   # Set admin users
   docker-compose -f docker-compose.prod.yml exec app \
     bundle exec rails runner "
       User.where(email: ['admin1@example.com', 'admin2@example.com']).update_all(admin: true)
     " RAILS_ENV=production
   ```

4. **T+85: Reindex Elasticsearch** (15-30 min)
   ```bash
   docker-compose -f docker-compose.prod.yml exec app \
     bundle exec rails runner "
       ParentItem.reindex
       Borrower.reindex
     " RAILS_ENV=production
   ```

5. **T+115: Smoke Tests** (15 min)
   - Login as admin
   - Search items
   - Search borrowers
   - View a lending
   - Create test lending (then delete)

6. **T+130: Switch Ports** (5 min)
   ```bash
   # Stop v1
   # (on v1 server)

   # Update Redux docker-compose to use port 80
   # Edit docker-compose.prod.yml: change 8080:80 to 80:80
   docker-compose -f docker-compose.prod.yml down
   docker-compose -f docker-compose.prod.yml up -d

   # Verify
   curl http://localhost/up
   ```

7. **T+135: Go Live** (5 min)
   - Test from external network
   - Monitor logs
   - Announce to users

8. **T+140-T+∞: Monitor** (24-48 hours)
   ```bash
   # Watch logs
   docker-compose -f docker-compose.prod.yml logs -f app

   # Monitor for errors
   docker-compose -f docker-compose.prod.yml logs app | grep -i error
   ```

## Rollback Plan

### Scenario 1: Migration Fails Before Go-Live

```bash
# 1. Stop Redux
docker-compose -f docker-compose.prod.yml down

# 2. Re-enable v1
# (remove maintenance page)

# 3. Fix issues and retry
```

### Scenario 2: Issues Found After Go-Live

**Within first 6 hours:**

```bash
# 1. Put Redux in maintenance mode
# 2. Switch ports back to v1
# 3. Restart v1
# 4. Announce rollback to users
# 5. Investigate and fix issues
# 6. Schedule new cutover
```

**After 6 hours:**
- Evaluate severity
- Prefer fixing forward
- If rollback necessary, any new Redux data must be manually migrated back to v1

## File Migration

### Paperclip Files (Asset Model)

v1 uses Paperclip ~> 4.2.0 for file attachments on the `Asset` model:

- `Asset` belongs_to `:parent_item` (not polymorphic)
- `ParentItem` has_many `:assets, dependent: :destroy`
- Path: `:rails_root/public/files/:hash/:filename`
- URL: `http://bonanza.fh-potsdam.de/files/:hash/:filename`
- Hash computed using `PAPERCLIP_HASH_SECRET` from environment
- Styles commented out — only original files stored
- No file type validation (`do_not_validate_attachment_file_type :file`)

**Migration steps:**

1. Query the `assets` table to understand scope:
   ```sql
   SELECT COUNT(*) FROM assets;
   SELECT file_file_name, file_content_type, file_file_size, parent_item_id FROM assets LIMIT 20;
   ```

2. Copy files from the server:
   ```bash
   rsync -avz root@SERVER:/path/to/bonanza/public/files/ ./v1_files/
   du -sh ./v1_files/
   ```

3. Get the Paperclip hash secret (needed to map Asset records to file paths):
   ```bash
   cat /proc/$(pgrep -f puma | head -1)/environ | tr '\0' '\n' | grep PAPERCLIP
   ```

4. File attachment strategy: **rsync files during migration, wire up ActiveStorage later.**
   Copy v1 Paperclip files (`public/files/`) to the Redux server during cutover.
   ActiveStorage integration is a separate post-migration task. Files remain
   accessible at their original paths via Caddy/nginx until ActiveStorage is set up.

### Avatar Data (Users + Borrowers)

The `avatar_data` field on both `users` and `lenders` in v1 is NOT a file upload.
It's an auto-generated Base64-encoded identicon from the RubyIdenticon gem:

```ruby
# User
self.avatar_data = Base64.strict_encode64(
  RubyIdenticon.create("#{first_name}#{last_name}#{department_id}", ...)
)

# Lender
self.avatar_data = Base64.strict_encode64(
  RubyIdenticon.create("#{first_name}#{last_name}#{email}", ...)
)
```

These are tiny (~200 byte) generated PNGs, not user uploads. Safe to drop entirely.
Redux has no avatar feature. Can regenerate on-the-fly if ever needed.

## Data Validation Checklist

### Automated Checks
- [ ] Record counts match between v1 and Redux
- [ ] No orphaned foreign keys
- [ ] All users have department memberships
- [ ] Lending states are valid
- [ ] Item statuses are valid
- [ ] All borrowers have required fields
- [ ] Elasticsearch indexes exist and are populated

### Manual Checks
- [ ] Sample 10 random users - verify data
- [ ] Sample 10 random borrowers - verify data
- [ ] Sample 10 random items - verify data
- [ ] Sample 10 random lendings - verify data
- [ ] Check oldest lending - verify history intact
- [ ] Check user with multiple department history
- [ ] Verify timestamps preserved (created_at, updated_at)

## Success Criteria

- [ ] 100% of critical data migrated (users, borrowers, items, lendings)
- [ ] All foreign keys valid
- [ ] All department memberships created
- [ ] Elasticsearch search working
- [ ] Zero critical bugs in first 24 hours
- [ ] User login successful
- [ ] Lending creation/return functional
- [ ] Total downtime under 4 hours
- [ ] v1 backup available for 30 days

## Known Issues & Limitations

### Data Not Migrated
1. **OAuth tokens** - Removed in Redux, users may need to reconnect services
2. **Avatar identicons** (`avatar_data`) - Auto-generated in v1, safe to drop. Redux will generate its own identicons.
3. **Links table** - Will be added to Redux before migration (git-bug 7f45b40)
4. **Bundles** - Feature removed

### Manual Post-Migration Tasks
1. Set admin flag on admin users
2. Review and update department memberships roles
3. Update TOS and privacy policy content
4. Test email notifications (not in v1)
5. Configure SMTP settings
6. Setup scheduled tasks (clockwork)

## Documentation

### Files Created
- `docs/migration/v1_schema.sql` - v1 database schema
- `docs/migration/v1_sample.sql` - Sample data for testing
- `docs/migration/v1_counts.txt` - Record counts from v1
- `docs/migration/v1_user_roles.csv` - User roles from v1
- `docs/migration/bonanza_migration.load` - pgloader config
- `docs/migration/migration.log` - Migration execution log
- `lib/tasks/migrate_v1_data.rake` - Data transformation
- `lib/tasks/import_v1_roles.rake` - User role import

### Reference
- [pgloader documentation](https://pgloader.io/)
- [PostgreSQL migration guide](https://www.postgresql.org/docs/current/migration.html)
- [Rails migrations](https://guides.rubyonrails.org/active_record_migrations.html)

## Resolved Questions

1. **v1 Access**: Fabian should have full access (SSH + MySQL). FHP IT can provide credentials if needed.
2. **Admin Users**: v1 role enum: guest=0, standard=1, leader=2, admin=3, deleted=99. Admin (role=3) gets leader role + User.admin=true. Standard (role=1) maps to member.
3. **Email Settings**: FHP provides SMTP relay for production email sending.
4. **File Uploads**: v1 uses Paperclip ~> 4.2.0 for the Asset model. Files stored at `public/files/:hash/:filename`. Avatar data is auto-generated identicons (safe to drop).
5. **Hosting**: Redux will run on the **same host** as v1, enabling parallel migration on different ports.
6. **v1 Status**: Running with low usage. Gives flexibility on cutover timing.

## Schema Dependency on a2 (Dependency Updates)

This migration plan assumes the current schema.rb. If a2 (Ruby 3.4 + Rails 8 upgrade) runs before d1, schema.rb will change -- migrations may be restructured, column types may differ, and new Rails 8 defaults may alter table definitions.

**This plan must be reviewed and updated after a2 completes.** Specifically:
- Verify pgloader field mappings against the final post-upgrade schema
- Re-test the migration script against a fresh Rails 8 database
- Update any schema version references

**Dependency a2:** Complete. Ruby 4.0.1 and Rails 8.1.2 are running. Schema is finalized.

## Still Open

- v1 Elasticsearch version (check during Phase 0)
- Preferred cutover weekend
- Who should be on-call during migration
