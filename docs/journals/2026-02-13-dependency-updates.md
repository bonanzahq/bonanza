# Dependency Updates Session - 2026-02-13

## Goal

Upgrade Ruby 3.1.2 -> 3.4.8, then Rails 7.0.4.3 -> 7.2.3 -> 8.0.4, then remaining gems.

## Baseline

- 200 tests, 0 real failures (when assets are built and ES is not running)
- Running tests locally with `TEST_DATABASE_PASSWORD=password` against Docker PG
- Need `pnpm build && pnpm build:css` before running tests (CI does this, we forgot locally)

## Approach

Each dependency change is a separate commit, manually verified by Fabian before proceeding.

## Completed

### Step 1: Ruby 3.1.2 -> 3.4.8

- Updated `mise.toml`, `Gemfile`, `Dockerfile`
- Removed `.ruby-version` (redundant with mise.toml + Dockerfile)
- Added `mutex_m`, `bigdecimal`, `drb` as explicit gems (extracted from Ruby stdlib in 3.4)
- All 200 tests pass, no deprecation warnings
- Commit: afa207e

### Entrypoint fix

- `docker-entrypoint.sh` used `db:create + db:migrate` but there are no migration files
- Changed to `db:prepare` which runs `schema:load` on fresh DB, `migrate` on existing
- This was causing empty databases in new worktrees
- Commit: 448b8f8

## Discoveries

- `db/schema.rb` gets emptied if `db:schema:dump` runs against an empty database.
  Rails overwrites the file. Restore with `git checkout -- db/schema.rb`.
- Docker build caches `COPY . .` layer. If schema.rb is dirty locally, the image
  bakes in the wrong version. Always ensure clean working tree before `docker compose build`.
- The containerization worktree's containers can block ports for other worktrees.
  Always `docker compose down` before removing a worktree.

## Next Steps

1. Rails 7.0.4.3 -> 7.2.3 (waiting for Fabian's go-ahead after testing Ruby 3.4.8)
2. Rails 7.2.3 -> 8.0.4
3. Security audit (bundle audit)
4. Phase 2 gems (Puma, Searchkick, Devise, Turbo, etc.)
