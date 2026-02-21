#!/bin/bash
# ABOUTME: Startup script for the Rails Docker container.
# ABOUTME: Waits for dependencies, prepares the database, then execs into CMD.

set -e

# URL-encode passwords to handle special characters safely
urlencode() {
  ruby -e "require 'uri'; puts URI::DEFAULT_PARSER.escape(ARGV[0], /[^A-Za-z0-9\-._~]/)" "$1"
}

# Resolve database connection variables based on environment.
# Development uses DEV_DATABASE_* prefix, production uses DB_* prefix.
if [ "$RAILS_ENV" = "production" ]; then
  PG_HOST="${DB_HOST:-db}"
  PG_PORT="${DB_PORT:-5432}"
  PG_USER="${DB_USER:-postgres}"
else
  PG_HOST="${DEV_DATABASE_HOST:-localhost}"
  PG_PORT="${DEV_DATABASE_PORT:-5432}"
  PG_USER="${DEV_DATABASE_USER:-postgres}"
fi

# Construct DATABASE_URL for production (database.yml handles dev/test via env vars)
if [ "$RAILS_ENV" = "production" ] && [ -n "${DB_PASSWORD:-}" ]; then
  ENCODED_DB_PASSWORD=$(urlencode "$DB_PASSWORD")
  export DATABASE_URL="postgresql://${DB_USER:-postgres}:${ENCODED_DB_PASSWORD}@${DB_HOST:-db}:${DB_PORT:-5432}/${DB_NAME:-bonanza_redux_production}"
fi

if [ -n "${ES_PASSWORD:-}" ]; then
  ENCODED_ES_PASSWORD=$(urlencode "$ES_PASSWORD")
  export ELASTICSEARCH_URL="http://elastic:${ENCODED_ES_PASSWORD}@${ES_HOST:-elasticsearch}:${ES_PORT:-9200}"
else
  export ELASTICSEARCH_URL="http://${ES_HOST:-elasticsearch}:${ES_PORT:-9200}"
fi

# Validate required environment variables in production
if [ "$RAILS_ENV" = "production" ]; then
  missing=""
  [ -z "${APP_HOST:-}" ] && missing="$missing APP_HOST"
  [ -z "${DB_PASSWORD:-}" ] && missing="$missing DB_PASSWORD"
  [ -z "${ES_PASSWORD:-}" ] && missing="$missing ES_PASSWORD"
  [ -z "${SECRET_KEY_BASE:-}" ] && missing="$missing SECRET_KEY_BASE"
  if [ -n "$missing" ]; then
    echo "Error: Required environment variables are not set:$missing"
    exit 1
  fi
fi

echo "Waiting for PostgreSQL..."
until pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -q; do
  sleep 2
done
echo "PostgreSQL is ready."

echo "Waiting for Elasticsearch..."
until curl -sf "${ELASTICSEARCH_URL}/_cluster/health" > /dev/null; do
  sleep 2
done
echo "Elasticsearch is ready."

if [ "$RAILS_ENV" != "production" ]; then
  # Sync dependencies into persistent volumes (no-ops when unchanged)
  echo "Installing dependencies..."
  bundle install
  pnpm install --frozen-lockfile
fi

# Ensure tmp directories exist (volume mount may overlay image filesystem)
mkdir -p tmp/pids tmp/cache tmp/storage

# Remove stale PID file left by a crashed container
rm -f tmp/pids/server.pid

echo "Setting up database..."
bundle exec rails db:prepare

if [ "$RAILS_ENV" = "production" ]; then
  echo "Running production bootstrap..."
  bundle exec rails bootstrap:admin
fi

if [ "$RAILS_ENV" != "production" ]; then
  bundle exec rails db:seed || echo "db:seed had errors (non-fatal, likely duplicate data)"
fi

if [ -z "${SKIP_REINDEX:-}" ]; then
  echo "Reindexing Elasticsearch..."
  bundle exec rails runner "ParentItem.reindex; Borrower.reindex" || echo "Reindex failed (non-fatal, run manually if needed)"
fi

exec "$@"
