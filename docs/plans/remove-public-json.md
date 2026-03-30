# Remove public/items.json and public/items2.json

## Problem

Two static JSON files in `public/` expose real equipment inventory data:

- `public/items.json` (14 KB) — ~570 equipment names from FH Potsdam
- `public/items2.json` (58 B) — 2 item names

These were added in the initial commit (`fa24937`) for an early autocomplete
feature. The only code reference is a commented-out line in
`app/javascript/controllers/autocomplete_controller.js`. Autocomplete now
uses a server endpoint, so these files are unused.

They exist on both `main` and `beta` branches.

## Option A: Simple Deletion (Recommended First Step)

Remove the files from HEAD via `git rm` and merge to beta/main.

**Pros:**
- Simple, no disruption to existing clones or forks
- Files stop being served immediately after deploy
- Sufficient if the concern is "stop exposing data going forward"

**Cons:**
- Data remains in git history — anyone with repo access can retrieve it
- `git log --all -p -- public/items.json` will still show the content

**Verdict:** Do this regardless of whether Option B is also pursued.

## Option B: Full History Rewrite

Use `git filter-repo` to remove the files from all commits, including the
initial commit.

**Pros:**
- Data becomes unrecoverable from the git history
- Clean history

**Cons:**
- All commit SHAs change (every commit after the initial one is rewritten)
- Every existing clone and fork becomes incompatible — requires coordinated
  force push and re-clone
- Both `main` and `beta` (protected branches) need force push
- GitHub PRs, issues referencing commit SHAs, and CI caches become stale
- Tags and releases need to be updated

**Commands (DO NOT EXECUTE without Fabian's approval):**

```bash
# 1. Ensure git-filter-repo is installed
brew install git-filter-repo

# 2. Work from a fresh full clone (not a worktree)
cd /tmp
git clone git@github.com:bonanzahq/bonanza.git bonanza-rewrite
cd bonanza-rewrite

# 3. Rewrite history to remove the files
git filter-repo --invert-paths \
  --path public/items.json \
  --path public/items2.json

# 4. Force push all branches
git remote add origin git@github.com:bonanzahq/bonanza.git
git push origin --force --all
git push origin --force --tags

# 5. All collaborators must re-clone or:
#    git fetch origin
#    git reset --hard origin/<branch>
```

**Verdict:** Only worth doing if the data is sensitive enough to warrant the
disruption. The files contain equipment type names (not personal data, not
credentials). Discuss with Fabian.

## Recommendation

Implement Option A now. Discuss Option B separately — the data is equipment
names, not secrets or personal information. The risk of it being in history
is low, but the decision is Fabian's.
