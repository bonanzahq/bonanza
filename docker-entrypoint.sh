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
until curl -sf http://elasticsearch:9200/_cluster/health > /dev/null; do
  sleep 2
done
echo "Elasticsearch is ready."

# Sync dependencies into persistent volumes (no-ops when unchanged)
echo "Installing dependencies..."
bundle install
CI=true pnpm install --frozen-lockfile

# Ensure tmp directories exist (volume mount may overlay image filesystem)
mkdir -p tmp/pids tmp/cache tmp/storage

# Remove stale PID file left by a crashed container
rm -f tmp/pids/server.pid

echo "Setting up database..."
bundle exec rails db:prepare 2>&1 || echo "db:prepare had errors (seeds may have failed, non-fatal)"

echo "Reindexing Elasticsearch..."
bundle exec rails runner "ParentItem.reindex; Borrower.reindex" || echo "Reindex failed (non-fatal, run manually if needed)"

exec "$@"
