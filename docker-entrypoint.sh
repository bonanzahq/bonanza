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

# Remove stale PID file left by a crashed container
rm -f tmp/pids/server.pid

echo "Running db:create and db:migrate..."
bundle exec rails db:create 2>/dev/null || true
bundle exec rails db:migrate

exec "$@"
