#!/usr/bin/env bash
# ABOUTME: Creates a full backup of v1 MySQL database and Paperclip files.
# ABOUTME: Run on the bare metal server before starting the migration.

set -euo pipefail

BACKUP_DIR="${1:-/root}"
V1_DIR="/var/www/bonanza"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Bonanza v1 Backup ==="
echo "Backup directory: $BACKUP_DIR"

# --- Parse MySQL credentials ---
MYSQL_USER="bonanzasql1"
MYSQL_DB="bonanzasql1"

if [ -z "${MYSQL_PWD:-}" ]; then
  MYSQL_PWD=$(
    grep -A 10 'production:' "$V1_DIR/config/database.yml" \
    | grep 'password:' \
    | head -1 \
    | sed 's/.*password:[[:space:]]*//' \
    | tr -d "'\"" \
    | tr -d '[:space:]'
  ) || true

  if [ -z "$MYSQL_PWD" ]; then
    echo "Could not parse MySQL password from $V1_DIR/config/database.yml"
    echo -n "Enter MySQL password for $MYSQL_USER: "
    read -rs MYSQL_PWD
    echo
  fi
  export MYSQL_PWD
fi

# --- MySQL dump ---
DB_BACKUP="$BACKUP_DIR/bonanza_v1_backup_${TIMESTAMP}.sql.gz"
echo "Dumping MySQL database..."
mysqldump -u "$MYSQL_USER" --single-transaction "$MYSQL_DB" \
  | gzip > "$DB_BACKUP"
echo "  $DB_BACKUP ($(du -h "$DB_BACKUP" | cut -f1))"

# --- Paperclip files ---
FILES_BACKUP="$BACKUP_DIR/bonanza_v1_files_${TIMESTAMP}.tar.gz"
echo "Backing up Paperclip files..."
tar czf "$FILES_BACKUP" -C / "var/www/bonanza/public/files/"
echo "  $FILES_BACKUP ($(du -h "$FILES_BACKUP" | cut -f1))"

# --- Summary ---
echo ""
echo "=== Backup Complete ==="
ls -lh "$DB_BACKUP" "$FILES_BACKUP"
echo ""
echo "Next: run 01-export-v1.sh"
