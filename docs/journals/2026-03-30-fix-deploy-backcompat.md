# fix-deploy-backcompat session

## Problem

`deploy.sh` accepts branch/tag/SHA refs but fails mid-run on older tags
(e.g. `v2.0.0`) because `docker/nginx-site.conf` was added in
`v2.0.0-beta.18` and doesn't exist at that ref. The `set -euo pipefail`
causes curl to abort on the 404, leaving partial state (4 of 5 files
written to the working directory).

GitHub issue: #269
git-bug: a940dcd

## Investigation

Scouted the file manifest across tags:

| File | Exists at v2.0.0 |
|------|-------------------|
| docker-compose.yml | yes |
| Caddyfile | yes |
| elastic_synonyms.txt | yes |
| example.env | yes |
| nginx-site.conf | **no** (added v2.0.0-beta.18) |

`nginx-site.conf` is a reference file for the host nginx config. It is
not mounted or referenced by `docker-compose.yml`, so it's purely
informational and not required to run the stack.

## Approach chosen

Hybrid: atomic required + optional fallback.

- **Required files** download to a temp directory first. If any fail,
  the script exits with a clear error listing all missing files. Nothing
  is written to the working directory.
- **Optional files** attempt download after required files succeed. A 404
  prints a skip warning and continues normally.
- `trap 'rm -rf "${TMPDIR}"' EXIT` ensures temp dir cleanup on any path.

Rejected alternatives:
- Pure atomic preflight (too strict — would reject valid old tags that
  run fine without nginx-site.conf)
- Pure optional fallback (risks silently skipping genuinely required files)

## Changes

- `deploy.sh`: replaced sequential curl calls with `REQUIRED_FILES` and
  `OPTIONAL_FILES` arrays, atomic temp-dir download for required files,
  graceful skip for optional files. Updated usage text to mention tags.
- `test/deploy_test.sh`: 5 test cases covering recent branch, old tag
  (required files present + optional skipped), invalid ref, help flag.

## [pattern] Adding files to deploy.sh

Future deployment files go into either the `REQUIRED_FILES` or
`OPTIONAL_FILES` array in `deploy.sh`. One-line change per file.
Files that existed since v1/v2.0.0 are required; files added later
should be optional to maintain backward compatibility with older tags.

## Outcome

- PR #275 against beta, review requested from ff6347
- git-bug a940dcd closed
- All 5 tests pass
