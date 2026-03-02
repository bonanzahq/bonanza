#!/usr/bin/env bash
# ABOUTME: Exports v1 MySQL data to JSONL files for migration to Redux.
# ABOUTME: Run on the bare metal server where v1 MySQL is running.

set -euo pipefail

EXPORT_DIR="${1:-/tmp/v1_export}"
V1_DIR="/var/www/bonanza"

echo "=== Bonanza v1 Data Export ==="
echo "Export directory: $EXPORT_DIR"

mkdir -p "$EXPORT_DIR"

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

mysql_q() {
  mysql -u "$MYSQL_USER" "$MYSQL_DB" --batch --raw -N -e "$1"
}

# Verify connection
echo "Testing MySQL connection..."
mysql_q "SELECT 1" > /dev/null
echo "Connected."
echo ""

export_table() {
  local name="$1"
  local query="$2"
  local outfile="$EXPORT_DIR/${name}.jsonl"

  echo -n "  $name... "
  mysql_q "$query" > "$outfile"
  echo "$(wc -l < "$outfile" | tr -d ' ') rows"
}

# --- Export all tables ---

export_table "departments" "
SELECT JSON_OBJECT(
  'id', id, 'name', name, 'room', room, 'note', note,
  'time', \`time\`, 'staffed', staffed,
  'staffed_at', staffed_at,
  'default_lending_duration', default_lending_duration,
  'created_at', created_at, 'updated_at', updated_at
) FROM departments ORDER BY id;
"

export_table "users" "
SELECT JSON_OBJECT(
  'id', id,
  'first_name', first_name, 'last_name', last_name,
  'email', email,
  'encrypted_password', encrypted_password,
  'reset_password_token', reset_password_token,
  'reset_password_sent_at', reset_password_sent_at,
  'remember_created_at', remember_created_at,
  'department_id', department_id,
  'role', role,
  'invitation_token', invitation_token,
  'invitation_created_at', invitation_created_at,
  'invitation_sent_at', invitation_sent_at,
  'invitation_accepted_at', invitation_accepted_at,
  'invitation_limit', invitation_limit,
  'invited_by_id', invited_by_id,
  'invited_by_type', invited_by_type,
  'invitations_count', invitations_count,
  'created_at', created_at, 'updated_at', updated_at
) FROM users ORDER BY id;
"

export_table "lenders" "
SELECT JSON_OBJECT(
  'id', id,
  'first_name', first_name, 'last_name', last_name,
  'student_id', student_id,
  'email', email, 'phone', phone,
  'tos_token', tos_token,
  'tos_accepted', tos_accepted,
  'id_checked', id_checked,
  'insurance_checked', insurance_checked,
  'type', \`type\`,
  'created_at', created_at, 'updated_at', updated_at
) FROM lenders ORDER BY id;
"

export_table "parent_items" "
SELECT JSON_OBJECT(
  'id', id,
  'name', name, 'description', description,
  'department_id', department_id, 'price', price,
  'storage_location', storage_location,
  'created_at', created_at, 'updated_at', updated_at
) FROM parent_items ORDER BY id;
"

export_table "items" "
SELECT JSON_OBJECT(
  'id', id,
  'uid', uid, 'quantity', quantity,
  'parent_item_id', parent_item_id,
  'status', status, 'condition', \`condition\`,
  'comment', comment,
  'created_at', created_at, 'updated_at', updated_at
) FROM items ORDER BY id;
"

export_table "lendings" "
SELECT JSON_OBJECT(
  'id', id,
  'note', note,
  'lender_id', lender_id,
  'lent_at', lent_at,
  'state', state, 'token', token,
  'user_id', user_id,
  'returned_at', returned_at,
  'duration', duration,
  'department_id', department_id,
  'notification_counter', notification_counter,
  'created_at', created_at, 'updated_at', updated_at
) FROM lendings ORDER BY id;
"

export_table "line_items" "
SELECT JSON_OBJECT(
  'id', id,
  'item_id', item_id, 'lending_id', lending_id,
  'quantity', quantity,
  'returned_at', returned_at,
  'created_at', created_at, 'updated_at', updated_at
) FROM line_items ORDER BY id;
"

export_table "item_histories" "
SELECT JSON_OBJECT(
  'id', id,
  'quantity', quantity, 'comment', comment,
  'condition', \`condition\`, 'status', status,
  'item_id', item_id, 'user_id', user_id,
  'line_item_id', line_item_id,
  'created_at', created_at, 'updated_at', updated_at
) FROM item_histories ORDER BY id;
"

export_table "conducts" "
SELECT JSON_OBJECT(
  'id', id,
  'kind', kind,
  'lender_id', lender_id,
  'user_id', user_id,
  'department_id', department_id,
  'lending_id', lending_id,
  'reason', reason,
  'duration', duration,
  'permanent', permanent,
  'created_at', created_at, 'updated_at', updated_at
) FROM conducts ORDER BY id;
"

export_table "accessories" "
SELECT JSON_OBJECT(
  'id', id,
  'name', name,
  'parent_item_id', parent_item_id,
  'created_at', created_at, 'updated_at', updated_at
) FROM accessories ORDER BY id;
"

export_table "accessories_line_items" "
SELECT JSON_OBJECT(
  'accessory_id', accessory_id,
  'line_item_id', line_item_id
) FROM accessories_line_items ORDER BY accessory_id, line_item_id;
"

export_table "tags" "
SELECT JSON_OBJECT(
  'id', id, 'name', name,
  'taggings_count', taggings_count
) FROM tags ORDER BY id;
"

export_table "taggings" "
SELECT JSON_OBJECT(
  'id', id,
  'tag_id', tag_id,
  'taggable_type', taggable_type,
  'taggable_id', taggable_id,
  'context', context,
  'tagger_type', tagger_type,
  'tagger_id', tagger_id,
  'created_at', created_at
) FROM taggings ORDER BY id;
"

export_table "links" "
SELECT JSON_OBJECT(
  'id', id,
  'url', url, 'title', title,
  'parent_item_id', parent_item_id,
  'created_at', created_at, 'updated_at', updated_at
) FROM links ORDER BY id;
"

# --- Summary ---
echo ""
echo "=== Export Summary ==="
for f in "$EXPORT_DIR"/*.jsonl; do
  printf "  %-30s %s rows\n" "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')"
done
echo ""
echo "Total size: $(du -sh "$EXPORT_DIR" | cut -f1)"
echo ""
echo "Export complete. Next: run 02-run-migration.sh"
