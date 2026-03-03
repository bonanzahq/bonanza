#!/usr/bin/env bash
# ABOUTME: Orchestrates the v1 data migration on the staging/production server.
# ABOUTME: Copies exported data and rake task into the Rails Docker container and runs them.

set -euo pipefail

EXPORT_DIR="${1:-/tmp/v1_export}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
SERVICE="${RAILS_SERVICE:-rails}"

echo "=== Bonanza v1 -> Redux Migration ==="
echo "Export dir:    $EXPORT_DIR"
echo "Compose file:  $COMPOSE_FILE"
echo "Rails service: $SERVICE"
echo ""

# --- Preflight checks ---

if [ ! -d "$EXPORT_DIR" ]; then
  echo "ERROR: Export directory not found: $EXPORT_DIR"
  echo "Run 01-export-v1.sh first."
  exit 1
fi

jsonl_count=$(find "$EXPORT_DIR" -name '*.jsonl' | wc -l | tr -d ' ')
if [ "$jsonl_count" -eq 0 ]; then
  echo "ERROR: No .jsonl files in $EXPORT_DIR"
  exit 1
fi
echo "Found $jsonl_count JSONL files in export directory."

if ! docker compose -f "$COMPOSE_FILE" ps "$SERVICE" 2>/dev/null | grep -qE "running|Up"; then
  echo "ERROR: Rails service '$SERVICE' is not running."
  echo "Start it with: docker compose -f $COMPOSE_FILE up -d"
  exit 1
fi

CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q "$SERVICE")
echo "Container: $CONTAINER"
echo ""

# --- Copy files into container ---

echo "--- Copying export data into container ---"
docker exec "$CONTAINER" mkdir -p /app/tmp/v1_export
docker cp "$EXPORT_DIR"/. "$CONTAINER:/app/tmp/v1_export/"
echo "Done."
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "--- Copying rake task into container ---"
docker cp "$SCRIPT_DIR/migrate_v1.rake" "$CONTAINER:/app/lib/tasks/migrate_v1.rake"
echo "Done."
echo ""

# --- Run migration ---

echo "--- Running migration (load) ---"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  bundle exec rails migrate:v1:load \
  V1_DATA_DIR=/app/tmp/v1_export RAILS_ENV=production
echo ""

echo "--- Running validation ---"
docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
  bundle exec rails migrate:v1:validate RAILS_ENV=production
echo ""

# --- Reindex Elasticsearch ---

echo "--- Reindexing Elasticsearch ---"

# Build ELASTICSEARCH_URL the same way the entrypoint does.
# docker compose exec bypasses the entrypoint, so env vars set there are missing.
ES_PASSWORD=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv ES_PASSWORD 2>/dev/null || true)
ES_HOST=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv ES_HOST 2>/dev/null || echo "elasticsearch")
ES_PORT=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" printenv ES_PORT 2>/dev/null || echo "9200")

# Trim trailing carriage returns from docker exec output
ES_PASSWORD=$(echo "$ES_PASSWORD" | tr -d '\r')
ES_HOST=$(echo "$ES_HOST" | tr -d '\r')
ES_PORT=$(echo "$ES_PORT" | tr -d '\r')

if [ -n "$ES_PASSWORD" ]; then
  ES_URL="http://elastic:${ES_PASSWORD}@${ES_HOST}:${ES_PORT}"
else
  ES_URL="http://${ES_HOST}:${ES_PORT}"
fi

docker compose -f "$COMPOSE_FILE" exec -T -e "ELASTICSEARCH_URL=$ES_URL" "$SERVICE" \
  bundle exec rails runner '
    puts "Reindexing ParentItems..."
    ParentItem.reindex
    puts "Reindexing Borrowers..."
    Borrower.reindex
    puts "Done."
  ' RAILS_ENV=production
echo ""

# Check ES indexes
echo "--- Elasticsearch indexes ---"
if [ -n "$ES_PASSWORD" ]; then
  docker compose -f "$COMPOSE_FILE" exec -T elasticsearch \
    curl -s -u "elastic:${ES_PASSWORD}" http://localhost:9200/_cat/indices?v 2>/dev/null || echo "(could not query ES)"
else
  docker compose -f "$COMPOSE_FILE" exec -T elasticsearch \
    curl -s http://localhost:9200/_cat/indices?v 2>/dev/null || echo "(could not query ES)"
fi
echo ""

echo "=== Migration complete ==="
echo ""
echo "Next steps:"
echo "  1. Smoke test: login, search, view a lending"
echo "  2. Compare data against v1 if on staging"
echo "  3. If OK, proceed with production cutover"
