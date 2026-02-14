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

### Phase 2: Gem updates

All completed in sequence, tests passing after each:

- **Batch 0**: Pinned all gems to exact resolved versions (project convention, no ~> ranges)
- **Batch 1**: cancancan 3.3.0 -> 3.6.1, redcarpet 3.5.1 -> 3.6.1, elasticsearch 8.4.0 -> 8.19.3
- **Batch 2**: Bumped load_defaults 7.2 -> 8.0, removed redundant to_time override
- **Batch 3**: turbo-rails 1.5.0 -> 2.0.23, @hotwired/turbo-rails npm 7.2.5 -> 8.0.23
- **Batch 4**: searchkick 5.5.2 -> 6.0.3 (removed Hashie dep, no API changes affected us)
- **Batch 5**: devise 4.9.4 -> 5.0.1 (devise_invitable 2.0.11 compatible)
- **Batch 6**: puma 6.6.0 -> 7.2.0 (simple config, no hooks to rename)

Skipped devise 5.x evaluation of breaking changes -- tests all pass, no issues found.
Skipped rubocop update -- already at latest resolved versions from Batch 0 pinning.

### CI and Renovate

- Added Docker build job to CI (runs in parallel with tests)
- Configured Renovate with shared config + Bundler-specific rules
- Added .github/renovate.json to CI paths-ignore

### Bugs filed

- `36a3852` - Investigate file storage persistence and backup strategy
- `58fe488` - Update shared Renovate config with Bundler rules
- `6f5b2a5` - Upgrade Rails 8.0.4 to 8.1.2
- `92396c5` - Upgrade Ruby 3.4.8 to 4.0.1

### Bugfix: invitation email

- Fabian found that inviting a user crashed with `undefined method 'department' for an instance of User`
- Template called `@resource.department` but User model only has `current_department`
- Fixed in both the hidden preheader (line 176) and visible body (line 223)
- Pre-existing bug, not caused by our upgrades

### Bugs closed

- `8d0fc12` - Execute a2: Dependency updates (Ruby 3.4+ / Rails 8.x) -- Phase 1 + 2 complete

### Final state

- Ruby 3.4.8, Rails 8.0.4, load_defaults 8.0
- All gems at latest stable, pinned to exact versions
- 200 tests pass, 0 failures, 0 deprecation warnings
- Docker builds in CI, Renovate configured
- Security audit clean
- PR #55 open: https://github.com/bonanzahq/bonanza/pull/55
- Branch: feat-dependency-updates (37 commits ahead of main)
- Fabian tested the app manually -- everything works

## Next session plan: Rails 8.1.2 + Ruby 4.0.1

Order: Rails first (minor, lower risk), then Ruby (major, higher risk).

### Phase 1: Rails 8.0.4 -> 8.1.2

1. Check gem compatibility -- `acts-as-taggable-on 13.0.0` has `activerecord < 8.2`, should work with 8.1.x but verify
2. Update Gemfile to `"8.1.2"`, run `bundle update rails`
3. Fix any dependency conflicts (bump blocking gems one at a time)
4. Run tests, fix failures
5. Check deprecation warnings
6. Check what `load_defaults 8.1` changes (read railties source)
7. Bump load_defaults 8.0 -> 8.1 in separate commit
8. Docker rebuild + smoke test
9. Push and verify CI

### Phase 2: Ruby 3.4.8 -> 4.0.1

10. Check `docker pull ruby:4.0.1` exists before starting
11. Install via mise: `mise install ruby@4.0.1`
12. Update Gemfile, mise.toml, Dockerfile
13. Run `bundle install` -- watch for native extension failures (bcrypt, pg, puma, nokogiri, oj, redcarpet)
14. Run tests -- Ruby 4.0 risks: frozen string literals by default, removed deprecated methods
15. Fix failures one at a time
16. Docker rebuild + smoke test
17. Push and verify CI

### Risks to watch

- **acts-as-taggable-on** has been the blocker on every Rails upgrade
- **ruby_identicon 0.0.6** is unmaintained and unused in app code -- consider removing before Ruby 4.0
- **Native extensions** may not compile on Ruby 4.0 -- need to bump gems with C extensions
- **Frozen string literals** (Ruby 4.0) could break gems doing `str << "bar"` on string literals
- **Docker image `ruby:4.0.1`** may not exist on Docker Hub yet
- **sprockets-rails** -- Rails 8.1 continues Propshaft push, watch for deprecations
