# Journal: 2026-02-10 (a1-yarn-to-pnpm)

## Session Summary

Completed the yarn-to-pnpm migration (plan a1). All build tooling now uses pnpm with pinned dependency versions. PR #29 created.

## Activities

### 1. Created .npmrc

Added `save-exact=true` so all future `pnpm add` commands pin exact versions.

### 2. Pinned package.json Dependencies

Removed `^` prefixes from all 12 dependencies. Added `pnpm.onlyBuiltDependencies` config to allow esbuild's postinstall script -- pnpm v10 requires explicit approval for packages that run build scripts.

### 3. Generated pnpm-lock.yaml

Clean install from pinned versions after deleting the pre-existing lockfile (which had been generated from unpinned versions).

### 4. Updated Procfile.dev and bin/setup

- `Procfile.dev`: `yarn build` / `yarn build:css` -> `pnpm build` / `pnpm build:css`
- `bin/setup`: added `pnpm install` step after `bundle install`

### 5. Updated Documentation

- `AGENTS.md`: removed "migration from yarn in progress" note
- `docs/ruby-tools-reference.md`: yarn -> pnpm in CLI examples

### 6. Committed Gemfile.lock Platform Addition

`arm64-darwin-25` was auto-added by Bundler on macOS 25. Unrelated to migration but committed to keep the tree clean.

## Technical Notes

- pnpm v10 introduced `onlyBuiltDependencies` -- packages with postinstall scripts must be explicitly allowlisted in package.json or approved interactively. esbuild needs this for its native binary download.
- `b1_containerization.md` already referenced pnpm (updated in a prior session), so no changes needed there.
- Build verification will be automated once CI/CD is set up (B4).

## Remaining

- PR #29 open for review
- `Gemfile.lock` platform change included in the branch but is not pnpm-related
