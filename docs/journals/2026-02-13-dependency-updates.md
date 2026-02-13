# Dependency Updates Session - 2026-02-13

## Goal

Upgrade Ruby 3.1.2 -> 3.4.8, then Rails 7.0.4.3 -> 7.2.3 -> 8.0.4, then remaining gems.

## Baseline

- 200 tests, 18 pre-existing errors (16 asset pipeline, 2 Elasticsearch)
- Running tests locally with `TEST_DATABASE_PASSWORD=password` against Docker PG from feat-containerization worktree
- Docker PG on port 5432 (from feat-containerization-db-1 container)

## Approach

Each dependency change is a separate commit, manually verified by Fabian before proceeding.

## Steps

### Step 1: Ruby 3.1.2 -> 3.4.8

Status: starting
