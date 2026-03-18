# Setup Releases Session

## What we did

Set up automated semantic versioning with a beta prerelease channel for Bonanza.

### Changes

1. **Installed semantic-release and plugins** as devDependencies:
   `semantic-release`, `@semantic-release/commit-analyzer`,
   `@semantic-release/release-notes-generator`, `@semantic-release/changelog`,
   `@semantic-release/npm`, `@semantic-release/git`, `@semantic-release/github`

2. **Created `release.config.cjs`** adapted from Fabian's preset:
   - `npmPublish: false` (no npm publishing)
   - Branches: `main` (stable), `beta` (prerelease)
   - Plugins: commit-analyzer, release-notes, changelog, npm (version bump only),
     git (commits CHANGELOG.md + package.json), github (creates releases)
   - Alpha channel was initially included but dropped to reduce complexity

3. **Created `.github/workflows/release.yml`**:
   - Triggers on push to `main` / `beta`
   - Uses `actions/create-github-app-token` with org-level `APP_ID` and
     `APP_PRIVATE_KEY` secrets (not a PAT — cleaner for org maintenance)
   - App tokens trigger downstream workflows unlike `GITHUB_TOKEN`

4. **Updated existing workflows** (`test.yml`, `docker-build.yml`):
   - Added `beta` branch to push/PR triggers
   - Added floating `beta` Docker tag for prerelease versions

5. **Fixed `package.json`**: added `version: "0.0.0"` field (needed by
   semantic-release npm plugin), fixed `private` from string to boolean

6. **Documented branching model in AGENTS.md**:
   `feature-branch -> beta (prerelease) -> main (stable release)`

7. **Tagged main HEAD as `v1.0.0`** and added a `feat!: Bonanza v2` breaking
   change commit so the first release on main will be `v2.0.0`

8. **Labeled `b0590e7`** (Ubuntu 22.04 -> 24.04 upgrade) with `p0`

### GitHub App setup

Fabian created a GitHub App ("Bonanza Release Bot") owned by the `bonanzahq`
org with Contents, Issues, and Pull requests read+write permissions. `APP_ID`
and `APP_PRIVATE_KEY` are stored as org secrets. Webhook is disabled (not needed).

### PR

PR #191 targets `beta` (not `main`). Once merged to beta, semantic-release
creates `v2.0.0-beta.1`. Merging beta to main produces stable `v2.0.0`.

### Decisions

- Dropped alpha prerelease channel — adds workflow overhead without clear value
- GitHub App over PAT — org-owned, not tied to individual accounts, any admin
  can manage keys
- semantic-release installed as project devDependency (not via npx)
- `release.config.cjs` over `.releaserc`

### Open items

- git-bug `2784348` stays open until PR #191 is merged
- Docker image size: devDependencies get installed in Docker builds since
  Dockerfile uses `pnpm install` without `--prod`. Tracked by existing issues
  `5af0461` (remove Node from prod image) and `4f8af1b` (switch to ruby-slim)
