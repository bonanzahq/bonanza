#!/bin/bash
# ABOUTME: Startup script for the Rails Docker container.
# ABOUTME: Waits for dependencies, prepares the database, then execs into CMD.

set -e

echo "Waiting for PostgreSQL..."
until pg_isready -h db -p 5432 -U postgres -q; do
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
if [ "$RAILS_ENV" != "production" ]; then
  bundle exec rails db:seed || echo "db:seed had errors (non-fatal, likely duplicate data)"
fi

if [ "$RAILS_ENV" != "production" ]; then
  echo "Reindexing Elasticsearch..."
  bundle exec rails runner "ParentItem.reindex; Borrower.reindex" || echo "Reindex failed (non-fatal, run manually if needed)"
fi

exec "$@"
