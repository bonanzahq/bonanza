# Dependency Updates Session - 2026-02-13

## Goal

Begin Phase A2: upgrade Ruby and Rails to supported versions, then remaining gems.
Target path: Ruby 3.4.8, Rails 7.0 -> 7.2.3 -> 8.0.4, then Phase 2 gems.

## What We Did

### Planning

- Read the full dependency update plan (`docs/plans/a2_dependency-updates.md`)
- Decided on staged Rails upgrade (7.0 -> 7.2 -> 8.0) instead of direct jump
- Decided on pinned versions (no `~>` ranges), Renovate/Dependabot for updates later
- Archived completed plans (a3, b1, b1b, b1c) to `docs/plans/archived/`

### Ruby 3.1.2 -> 3.4.8

- Updated `mise.toml`, `Gemfile`, `Dockerfile`
- Removed `.ruby-version` (redundant with mise.toml + Dockerfile)
- Added `mutex_m`, `bigdecimal`, `drb` gems (extracted from Ruby stdlib in 3.4)
- All 200 tests pass, no deprecation warnings

### Infrastructure fixes discovered along the way

**`docker-entrypoint.sh` bug:** Used `db:create` + `db:migrate` but there were
no migration files in the repo. Changed to `db:prepare` which does `schema:load`
on fresh databases and `migrate` on existing ones.

**Missing initial migration:** The project had no `db/migrate/` files at all.
Database setup relied entirely on `schema.rb`, which Rails silently overwrites
with an empty file if `db:schema:dump` runs against an empty database. Created
`db/migrate/20230403060517_initial_schema.rb` from schema.rb so `db:migrate`
always works. Timestamp matches existing schema version so it's a no-op on
existing databases.

**Docker worktree port conflicts:** The containerization worktree's Docker
containers were still running, blocking ports. Added cleanup instructions to
the worktree-level `AGENTS.md` (always `docker compose down` before removing
a worktree).

### Documentation

- Added "Development Environment Setup" section to project `AGENTS.md`
  (Docker setup, running tests locally, reindexing ES)
- Updated worktree `AGENTS.md` with Docker cleanup warning
- Updated tech stack versions in project `AGENTS.md`

### Bugs filed

- `f7f2187` - Autocomplete broken when accessing app from network (non-localhost, LAN, Tailscale)
- `c960606` - Returns view needs search functionality

## Key Lessons

1. **Build assets before running tests locally.** CI does `pnpm build && pnpm build:css`
   before tests. Without this, 16 controller tests fail on missing `application.css`.
   Without ES running, all 200 tests pass cleanly.

2. **`db/schema.rb` is fragile.** Rails overwrites it silently. Always have migration
   files as a safety net. Now we do.

3. **Docker layer caching.** If the working tree has dirty files, `docker compose build`
   bakes in the wrong version. The `COPY . .` layer uses the working tree, not git HEAD.

## Next Session

1. Fabian confirms Ruby 3.4.8 works (app running at localhost:3000)
2. Rails 7.0.4.3 -> 7.2.3 (first leg of staged upgrade)
3. Rails 7.2.3 -> 8.0.4
4. Security audit (`bundle audit`)
5. Phase 2 gems (Puma, Searchkick, Devise, Turbo, etc.)

Each step: update, test, commit, get Fabian's confirmation before proceeding.
