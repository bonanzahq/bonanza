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

### Ruby 3.1.2 -> 3.4.8 (DONE, committed)

- Updated `mise.toml`, `Gemfile`, `Dockerfile`
- Removed `.ruby-version` (redundant with mise.toml + Dockerfile)
- Added `mutex_m`, `bigdecimal`, `drb` gems (extracted from Ruby stdlib in 3.4)
- All 200 tests pass, no deprecation warnings

### Infrastructure fixes (DONE, committed)

- **`docker-entrypoint.sh`**: Changed `db:create + db:migrate` to `db:prepare`
  (the old approach did nothing because there were no migration files)
- **Initial migration**: Created `db/migrate/20230403060517_initial_schema.rb`
  from schema.rb so `db:migrate` always works on fresh databases
- **Docs**: Added dev environment setup section to AGENTS.md, Docker cleanup
  warning to worktree AGENTS.md

### Rails 7.0.4.3 -> 7.2.3 (IN PROGRESS, NOT committed)

Current state: Gemfile and config changes are made but tests hang.

**Gemfile changes made (uncommitted):**
- `rails` 7.0.4.2 -> 7.2.3
- `puma` ~5.0 -> 6.6.0
- `acts-as-taggable-on` ~9.0.0 -> 11.0.0 (10.0.0 was incompatible with Rails 7.2)
- `minitest` pinned to 5.25.4 (minitest 6.0.1 broke API, incompatible with Rails 7.2)
- `bundle install` succeeded, lockfile resolved

**Config changes made (uncommitted):**
- `config/environments/development.rb`: `cache_classes` -> `enable_reloading`
- `config/environments/production.rb`: `cache_classes` -> `enable_reloading`, logger syntax
- `config/environments/test.rb`: `cache_classes` -> `enable_reloading`, `show_exceptions` -> `:none`
- Kept `config.load_defaults 7.0` (do NOT bump yet)
- Left `ActiveRecord::Schema[7.0]` and migration `[7.0]` as-is

**Problem: tests hang.** Running `bin/rails test` prints "# Running:" then
hangs indefinitely. Running a single test file with `ruby -Itest` shows an
`ArgumentError: wrong number of arguments (given 3, expected 1..2)` in
`rails/test_unit/line_filtering.rb:7` but then also hangs.

The minitest pin to 5.25.4 resolved the explicit error but tests still hang.
This needs debugging next session.

**Possible causes to investigate:**
- Minitest 5.25.4 may still have compatibility issues with Rails 7.2 parallel test runner
- The `parallelize(workers: :number_of_processors)` in test_helper.rb may be problematic
- Try running with `parallelize(workers: 1)` or `--no-parallel` to isolate
- Check if `Searchkick.disable_callbacks` in setup block causes a hang with new Rails
- Try running a single test: `bin/rails test test/models/user_test.rb:10 -v`

### Bugs filed

- `f7f2187` - Autocomplete broken when accessing app from network (non-localhost, LAN, Tailscale)
- `c960606` - Returns view needs search functionality

## Commits on feat-dependency-updates

```
ef5bbff docs: simplify schema.rb warning now that migration exists
7293dba feat: add initial migration from schema.rb
6fb8248 docs: strengthen schema.rb warning in dev setup docs
d8d1da8 docs(a2): update dependency updates journal
28499a0 docs: add development environment setup instructions to AGENTS.md
448b8f8 fix: use db:prepare instead of db:create+db:migrate in entrypoint
a679b4b docs(a2): start dependency updates journal
afa207e feat: upgrade Ruby from 3.1.2 to 3.4.8
249a93f docs: archive completed plan files (a3, b1, b1b, b1c)
```

## Uncommitted changes (working tree)

```
Gemfile          - rails 7.2.3, puma 6.6.0, acts-as-taggable-on 11.0.0, minitest 5.25.4
Gemfile.lock     - regenerated
config/environments/development.rb  - enable_reloading
config/environments/production.rb   - enable_reloading, logger
config/environments/test.rb         - enable_reloading, show_exceptions
```

## Next session checklist

1. Debug the test hang (start with single test, verbose, no parallelization)
2. Get all 200 tests passing on Rails 7.2.3
3. Commit the Rails 7.2 upgrade
4. Rebuild Docker, smoke test, get Fabian's confirmation
5. Then: Rails 7.2.3 -> 8.0.4
6. Then: security audit, Phase 2 gems

## Docker state

- Containers running on feat-dependency-updates (ports 3000, 5432, 9200, 8025)
- App is on Ruby 3.4.8 / Rails 7.0.4.3 in the container (not yet rebuilt with 7.2)
- Test DB needs to be on the Docker PG: `TEST_DATABASE_PASSWORD=password`
