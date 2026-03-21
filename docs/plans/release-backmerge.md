# Release Backmerge Automation

## Problem

Bonanza uses semantic-release with two branches: `main` (stable releases) and
`beta` (prereleases). When semantic-release creates a release on `main`, it
commits version bumps to `package.json`, `pnpm-lock.yaml`, and `CHANGELOG.md`.
Beta doesn't know about these commits, so its next prerelease increments from
a stale base. This requires a manual backmerge of `main` into `beta` after
every release.

## Options Evaluated

### 1. semantic-release-backmerge (saitho)

The original plugin (`@saitho/semantic-release-backmerge`). Archived in Oct
2025, 16 open issues, no longer maintained. Not viable.

### 2. semantic-release-backmerge (kilianpaquier)

Active fork (`@kilianpaquier/semantic-release-backmerge`). 6 stars, single
maintainer, 1,147 lines of code supporting 5 platforms (GitHub, GitLab, Gitea,
Bitbucket, Bitbucket Cloud). Well-tested with PR fallback on conflicts.

Rejected because: we only need GitHub, the plugin adds 12 transitive
dependencies, and if abandoned (like saitho's) we're back to square one.

### 3. Custom semantic-release plugin

A local plugin exporting a `success` hook. Would work but adds ceremony
for what's essentially a few git commands. The semantic-release lifecycle
doesn't provide anything we can't get from `github.ref` in the workflow.

### 4. GitHub Actions workflow step (chosen)

A shell step after `semantic-release` in the release workflow. ~25 lines,
zero dependencies, transparent in workflow logs.

## Chosen Approach

A post-release workflow step that:

1. Fetches the latest `beta` branch
2. Sets `merge=ours` for release artifacts (`CHANGELOG.md`, `package.json`,
   `pnpm-lock.yaml`) to auto-resolve version number conflicts
3. Attempts `git merge main` into `beta`
4. On success: pushes directly
5. On conflict: creates a PR from `main` to `beta` for manual resolution
6. Skips PR creation if one already exists

Uses the GitHub App token (not `GITHUB_TOKEN`) so the push can trigger
downstream workflows like Docker Build.

## POC

Validated at https://github.com/ff6347/semantic-release-backmerge-poc with:

- Fast-forward merge path (automatic push)
- Conflict path (automatic PR creation)
- `merge=ours` for release artifacts (prevents false conflicts)
- Duplicate PR detection
- Graceful degradation on permission errors
