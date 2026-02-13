# Dependency Updates Session - 2026-02-13

## Goal

Phase A2: upgrade Ruby and Rails to supported versions, then remaining gems.
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

---

## Session 2 (continued)

### Rails 7.2.3 upgrade (DONE, committed)

Resolved the test hang and completed the 7.2 upgrade:

- **Parallel test hang**: Tests hung with `parallelize(workers: :number_of_processors)` on Rails 7.2. Fixed by setting `parallelize(workers: 1)` -- small test suite doesn't benefit from parallelization.
- **Enum deprecation warnings**: Updated all 10 enum declarations across 8 model files from keyword-arg to positional-arg syntax.
- **load_defaults bumped to 7.2**: No `serialize` usage or `to_time` calls, so safe to bump directly. Tests pass.
- **Docker rebuilt and smoke tested**: App boots, login page returns 200.

### Rails 7.2.3 -> 8.0.4 (DONE, committed)

- **acts-as-taggable-on**: v11 required `activerecord < 8.0`, had to bump to v13.0.0
- **Removed stdlib shims**: `mutex_m`, `bigdecimal`, `drb` -- Rails 8 handles these
- **Devise mapping issue**: Rails 8 doesn't eagerly load routes in test env, causing `sign_in` to fail with "Could not find a valid mapping". Fixed by adding `Rails.application.reload_routes!` in test_helper.rb.
- **to_time deprecation**: Added `config.active_support.to_time_preserves_timezone = :zone` to application.rb
- **Tests**: 200 runs, 0 failures, 2 pre-existing ES errors, 0 deprecation warnings
- **Docker rebuilt and smoke tested**: App boots, login page returns 200
- **Security audit**: 0 vulnerabilities

### Commits (session 2)

```
5bd0bf5 fix: reload routes in test setup for Devise mapping compatibility
4d06e14 chore: set to_time_preserves_timezone for Rails 8.1 compat
5e870a4 chore: upgrade Rails from 7.2.3 to 8.0.4
fe9a723 chore: bump load_defaults from 7.0 to 7.2
bb7e381 fix: set parallel test workers to 1 to prevent hang on Rails 7.2
a34994f refactor: update enum declarations to positional arg syntax
f481a29 chore: upgrade Rails from 7.0.4.3 to 7.2.3
```

All pushed to origin/feat-dependency-updates.

## Next steps

Phase 1 (critical) is complete: Ruby 3.4.8, Rails 8.0.4.

Phase 2 (important gem updates) remains:
1. Searchkick & Elasticsearch update
2. Devise/cancancan/devise_invitable update
3. Turbo/Stimulus update
4. Puma update
5. Asset pipeline gems
6. RuboCop update
7. Bump `config.load_defaults` to 8.0 (incremental, use new_framework_defaults_8_0.rb)

## Docker state

- Containers running on feat-dependency-updates (ports 3000, 5432, 9200, 8025)
- App is on Ruby 3.4.8 / Rails 8.0.4
- Test DB needs `TEST_DATABASE_PASSWORD=password`
