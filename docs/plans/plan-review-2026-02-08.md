# Plan Review Notes

Review of all migration plans in `docs/plans/` performed during repo setup.

## Staleness Issues (plans are from October 2025)

### a2 (Dependency Updates)
- Version targets need refresh: check Ruby 3.4.2+/3.5.x status, Rails 8.0.5+
- Ruby 3.5 has been out ~2 months now -- evaluate stability
- EOL dates throughout the document need updating

### b1 (Containerization)
- Still references Ruby 3.1.2 / Rails 7.0.4.2 as base image
- Dockerfile code examples use `yarn` in builder stage despite project being pnpm
- Plan text says pnpm but code snippets contradict this in multiple places

### b4 (CI/CD)
- GHCR image path references `philippgeuder` but repo is under `bonanzahq`
- Needs org/path correction throughout

### c1 (Background Jobs)
- References `solid_queue ~> 0.3` (pre-release)
- Solid Queue is now a standard Rails 8 component; installation steps differ on Rails 8

## Substantive Concerns

### a1 (Yarn to pnpm)
- Partially done: `yarn.lock` and `yarn-error.log` already deleted in repo setup
- Remaining work: pin exact versions in `package.json`, create `.npmrc`, run `pnpm install`, update `Procfile.dev` and `bin/setup`
- References updating `CLAUDE.md` and `AGENTS.md` which no longer exist

### a2 (Dependency Updates)
- 1880 lines long, ~60% is communication templates, alternative paths, monitoring checklists, budget estimates
- Core strategy (Ruby 3.4 + Rails 8 direct) is sound
- Needs distilling to implementation steps + testing checklist before execution

### a3 (Testing)
- Suggests `database_cleaner-active_record` alongside Rails' built-in transactional tests
- For Minitest with Rails, transactional fixtures usually suffice; adding both creates confusion
- Pick one cleanup strategy

### b2 (Error Handling)
- `rescue_from StandardError` in ApplicationController is heavy-handed; can swallow bugs in development
- Should be production-only or always log at error level

### b3 (Devise + Turbo)
- More checklist than plan, which is fine for the scope
- Option A (disable Turbo on Devise forms) is pragmatic and correct

### c1 + c2 (Background Jobs + Email)
- Execution order correctly says combine these
- c2 rake task examples use `.deliver_now` but a separate section says "MUST use `.deliver_later`"
- Plan contradicts itself; needs reconciliation

### c3 (Conduct System)
- PostgreSQL interval queries look correct
- Warning escalation rule (2 warnings = 30-day auto-ban) is a business decision that needs confirmation
- What threshold and duration?

### c4 (GDPR)
- Retention periods (24 months inactive, 7 years with history per HGB) are reasonable defaults
- Plan itself says "consult legal counsel" -- don't deploy without doing that

### d1 (Data Migration)
- pgloader config and field mappings are well thought out
- Gap: doesn't account for schema differences after Rails 8 upgrade (a2)
- If a2 runs before d1, schema.rb will differ from what the migration plan assumes
- Migration should be planned against the final schema

### d2 (VPN)
- Just a note, not a plan. Fine as-is.

## Missing Plans

1. **No CLAUDE.md** -- `AGENTS.md` and symlinked `CLAUDE.md` were deleted in cleanup. Project needs a proper `CLAUDE.md` for Claude Code usage.
2. **No `docs/SPEC.md`** -- should exist per project conventions. No high-level spec has been written.
3. **No plan for `docs/bonanza-dev-notes/` cleanup** -- contains Obsidian canvas files and repomix output dumps from the review. These are reference artifacts, not project docs. Owner should decide what to keep.

## Execution Order Concern

A3 (testing) should overlap with or precede A2 (dependency updates), not follow it. Tests should exist *before* the upgrade so they can verify it doesn't break things. Current sequencing puts testing after the upgrade.

## Summary

Plans are a solid starting point but need a refresh pass before execution:
- Version numbers are 4 months stale
- Some code examples contradict plan text (yarn vs pnpm, deliver_now vs deliver_later)
- GHCR org reference is wrong
- a2 is bloated and needs trimming
- Execution order should be reconsidered for testing
