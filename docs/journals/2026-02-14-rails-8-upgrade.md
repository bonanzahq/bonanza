# Rails 8.0 Upgrade Session - 2026-02-14

## Goal

Complete the Rails upgrade path (7.0 -> 7.2 -> 8.0) started in the previous session,
add CI Docker build, and configure Renovate for automated dependency updates.

## What we did

### Rails 7.2.3 completion (picked up from previous session)

Previous session left Rails 7.2 changes uncommitted with tests hanging.

- **Parallel test hang**: Root cause was `parallelize(workers: :number_of_processors)`.
  Rails 7.2 changed parallel test infrastructure. Fixed by setting `workers: 1` --
  200 fast tests don't benefit from parallelization overhead.
- **Enum deprecations**: Updated all 10 enum declarations across 8 model files
  from keyword-arg to positional-arg syntax.
- **load_defaults 7.2**: Bumped safely. No `serialize` usage or `to_time` calls in codebase.
- Docker rebuilt, smoke tested, all green.

### Rails 7.2.3 -> 8.0.4

- **acts-as-taggable-on**: v11 had `activerecord < 8.0` constraint. Bumped to v13.0.0.
- **Removed stdlib shims**: `mutex_m`, `bigdecimal`, `drb` -- Rails 8 depends on these directly.
- **Devise mapping failure**: Rails 8 doesn't eagerly load routes in test env, so
  `Devise.mappings` was empty when `sign_in` ran. Fixed with `Rails.application.reload_routes!`
  in test_helper.rb.
- **to_time deprecation**: Added `config.active_support.to_time_preserves_timezone = :zone`
  as override for load_defaults 7.2. This becomes redundant when bumping to load_defaults 8.0.
- Tests: 200 runs, 0 failures, 2 pre-existing ES errors, 0 deprecation warnings.
- Docker rebuilt, smoke tested, security audit clean.

### CI: Docker build verification

Added a `docker-build` job to `.github/workflows/test.yml` that runs in parallel with
the test job. Build-only (`push: false`), no registry login needed. Uses `setup-buildx-action`
and `build-push-action`.

### Renovate configuration

- Added `.github/renovate.json` extending the shared config at `github>bonanzahq/renovate-config`.
- Shared config is npm-focused (matchDepTypes: dependencies/devDependencies), so added
  local overrides for Bundler:
  - Rails framework gems grouped together
  - Ruby minor/patch updates grouped
  - Ruby major updates grouped separately
- Filed git-bug `58fe488` to update the shared config with Bundler rules later.
- Added `.github/renovate.json` to CI paths-ignore.

### AGENTS.md updates

- Ruby: removed historical "upgraded from 3.1.2" note
- Rails: updated from "7.0.4.3 (EOL)" to "8.0.4"
- Test directory: "framework not yet configured" -> "200 tests"

### Bugs filed

- `36a3852` - Investigate file storage persistence and backup strategy
  (ActiveStorage local disk in Docker volume, no backup for files or DB)
- `58fe488` - Update shared Renovate config with Bundler rules

## Technical insights

- `config.load_defaults` is cumulative: 8.0 calls `load_defaults "7.2"` first, then applies
  8.0 overrides. So `to_time_preserves_timezone = :zone` is set at 8.0 level, defaults to
  `:offset` at 7.2 and below.
- `db:prepare` vs `db:migrate`: prepare does schema:load on fresh DB, migrate on existing.
  Both work for us now that we have the initial migration, but prepare is more robust.
- Rails 8 lazy-loads routes in test env. Any gem that populates state during route loading
  (like Devise mappings) needs `reload_routes!` in test setup.
- acts-as-taggable-on has strict activerecord upper bounds per major version. Always check
  before Rails upgrades.

## Current state

- Ruby 3.4.8, Rails 8.0.4, load_defaults 7.2
- All tests pass, Docker builds in CI, Renovate configured
- PR #55 open: https://github.com/bonanzahq/bonanza/pull/55
- Branch: feat-dependency-updates (28 commits ahead of main)

## Next steps

- Phase 2 gem updates (searchkick, devise, cancancan, turbo-rails, puma, rubocop)
- Bump load_defaults to 8.0 (use new_framework_defaults_8_0.rb for incremental opt-in)
- Set up Docker Hub push in CI (separate task)
