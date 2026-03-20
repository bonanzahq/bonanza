# Migration Scripts

Transfer these scripts to the staging/production server and run them.
No repo clone needed — just the files listed below.

## Files

| File | Runs on | Purpose |
|------|---------|---------|
| `00-backup-v1.sh` | bare metal | Backup v1 MySQL database and Paperclip files |
| `01-export-v1.sh` | bare metal | Export v1 MySQL data to JSONL |
| `migrate_v1.rake` | Docker (Rails) | Import + transform + validate |
| `02-run-migration.sh` | bare metal | Orchestrate: copy files, run rake tasks, reindex ES |
| `reindex.rb` | Docker (Rails) | Clean stale ES indices and reindex |

## Prerequisites

- v1 running at `/var/www/bonanza/` with MySQL `bonanzasql1`
- Redux Docker stack running (`docker compose -f docker-compose.prod.yml up -d`)
- Redux database schema loaded (the Docker entrypoint does this automatically)

## Usage

```bash
# Transfer scripts to server
scp -r scripts/migration/ root@SERVER:/root/migration/

# SSH into server
ssh root@SERVER
cd /root/migration
chmod +x 01-export-v1.sh 02-run-migration.sh
```

### Production only: clean up duplicate student_id first

```bash
export MYSQL_PWD='<password>'
mysql -u bonanzasql1 bonanzasql1 -e "
  UPDATE lenders SET student_id = NULL WHERE id IN (1170, 1171);
"
```

### Run

```bash
# Step 1: Export v1 data
./01-export-v1.sh /tmp/v1_export

# Step 2: Run migration (loads data, validates, reindexes ES)
./02-run-migration.sh /tmp/v1_export
```

### Configuration

The orchestrator accepts environment variables:

```bash
COMPOSE_FILE=docker-compose.prod.yml  # Docker Compose file
RAILS_SERVICE=rails                    # Docker service name for Rails
```

Example:

```bash
COMPOSE_FILE=docker-compose.yml RAILS_SERVICE=web ./02-run-migration.sh /tmp/v1_export
```

## Re-running

The migration is idempotent — it truncates all target tables before loading.
Safe to re-run if something goes wrong.

## What the migration does

1. Exports all v1 tables as JSONL (one JSON object per row)
2. Loads into Redux tables with column renames:
   - `lenders` -> `borrowers` (first_name->firstname, type->borrower_type, etc.)
   - `users.department_id` -> `current_department_id`, drops role/OAuth/avatar
   - `items.comment` -> `note`, adds storage_location from parent_items
   - `lendings.lender_id` -> `borrower_id`
   - `conducts.lender_id` -> `borrower_id`
   - `item_histories.comment` -> `note`
3. Creates `department_memberships` from v1 user roles:
   - guest(0)->guest, standard(1)->member, leader(2)->leader, admin(3)->leader+admin flag
4. Calculates `lending_counter` for each item from line_items
5. Sets `confirmed_at` on all users (so Devise doesn't block login)
6. Creates placeholder legal_texts (TOS + privacy policy)
7. Anonymizes deleted borrowers
8. Resets PostgreSQL sequences
9. Reindexes Elasticsearch (ParentItem + Borrower)

## Validation checks

- Record counts match v1
- All users have department memberships
- Admin users listed
- No orphaned foreign keys
- Storage locations redistributed
- Lending counters calculated
- Deleted borrowers anonymized
- Users confirmed (can log in)

## Timezone note

v1 stores timestamps without timezone info. The import script sets
`SET timezone = 'Europe/Berlin'` so timestamps are interpreted as Berlin time.
After migration, verify timestamps look correct in the UI.
