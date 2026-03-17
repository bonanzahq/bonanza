# Bonanza

Equipment lending management system for FH Potsdam. Rewrite of Bonanza v1.

## Tech Stack

- **Language**: Ruby 4.0.1
- **Framework**: Rails 8.1.2
- **Database**: PostgreSQL 15
- **Search**: Elasticsearch 8.4 via Searchkick
- **Frontend**: Hotwire (Turbo + Stimulus), esbuild, Sass
- **Auth**: Devise + devise_invitable, CanCanCan for authorization
- **Package Manager**: pnpm
- **Version Manager**: mise (`mise.toml`)

## Core Models

- `User` -- staff members, belong to departments with roles (admin/leader/member/guest/hidden)
- `Department` -- organizational unit, scopes all data
- `Borrower` -- people who borrow equipment, self-register or staff-created
- `ParentItem` -- equipment type (e.g. "Sony A7 Camera")
- `Item` -- individual piece of equipment with UID, belongs to ParentItem
- `Lending` -- state machine: cart -> borrower -> confirmation -> completed
- `LineItem` -- join between Lending and Item
- `Conduct` -- warnings and bans for borrowers
- `Ability` -- CanCanCan authorization rules per role

## Development Environment Setup

### Docker (full stack)

The application runs in Docker containers. To start a fresh environment:

```bash
cd ~/Documents/bonanzahq/bonanza/<worktree>/docker

# Start all services (builds image if needed)
docker compose up -d

# The entrypoint automatically:
#   1. Waits for PostgreSQL and Elasticsearch
#   2. Runs db:prepare (schema:load on fresh DB, migrate on existing)
#   3. Seeds the database
#   4. Reindexes Elasticsearch (dev only; skipped in production)
#   5. Starts Rails with foreman (web + js + css watchers)
```

The app is available at `http://localhost:3000`. Caddy reverse proxy is on
port 80/443. Mailpit UI is at `http://localhost:8025`.

Default seed credentials: `admin@example.com` / `platypus-umbrella-cactus`

If the database or ES get into a bad state, nuke everything and restart:

```bash
cd docker
docker compose down -v    # -v removes volumes (DB data, ES data)
docker compose up -d      # Fresh start
```

**Building without Compose:** The Dockerfile expects the repository root as
build context. `docker compose` handles this via `context: ..` in the compose
files, but standalone builds must run from the repo root:

```bash
# Production image (default target)
docker build -f docker/Dockerfile .

# Development image (includes Node.js for asset watchers)
docker build -f docker/Dockerfile --target development .
```

Do NOT run `docker build .` from inside `docker/` — the context will be wrong
and the build will fail.

**pnpm in Docker:** pnpm will fail with `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`
if `node_modules` needs recreating and there's no TTY. `ENV CI=true` in the
Dockerfile handles this. Do NOT add workarounds elsewhere -- the fix is already
in place.

**Note on `db/schema.rb`:** Rails can silently overwrite schema.rb with an
empty schema if `db:schema:dump` runs against an empty database. This is
harmless now because `db/migrate/` has the initial migration, but don't
commit a truncated schema.rb. If it happens: `git checkout -- db/schema.rb`.

### Running tests locally

Tests run outside Docker but need a PostgreSQL instance on `localhost:5432`.
The Docker Compose override exposes the DB on port 5432, so you can reuse it
if the stack is running. Otherwise, start a standalone container:

```bash
# Start a test-only PostgreSQL container (one-time, or after it's been removed)
# Uses postgres/postgres credentials to match database.yml defaults
docker run -d --name bonanza-test-db -p 5432:5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres postgres:17.7

# Create the test database (first time or after volume loss)
# No env vars needed -- defaults match the container above
mise exec -- bundle exec rails db:create
mise exec -- bundle exec rails db:schema:load
mise exec -- bundle exec rails db:test:prepare

# Build assets first (required for controller tests)
pnpm install --frozen-lockfile
pnpm build && pnpm build:css

# Run tests (mise picks up Ruby from mise.toml)
mise exec -- bundle exec rails test

# Stop the container when done (data persists)
docker stop bonanza-test-db

# Restart it later
docker start bonanza-test-db
```

If port 5432 is already in use (e.g. by Docker Compose), stop that first.
To use a different port, set `DEV_DATABASE_PORT` and `TEST_DATABASE_PORT`.

The database config in `config/database.yml` uses env vars for all environments:

- **Development**: `DEV_DATABASE_HOST`, `DEV_DATABASE_PORT`, `DEV_DATABASE_USER`,
  `DEV_DATABASE_PASSWORD`, `DEV_DATABASE_NAME` (defaults: localhost:5432, postgres/postgres)
- **Test**: `TEST_DATABASE_HOST`, `TEST_DATABASE_PORT`, `TEST_DATABASE_USER`,
  `TEST_DATABASE_PASSWORD`, `TEST_DATABASE_NAME` (defaults: localhost:5432, postgres/postgres)
- **Production**: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`

```bash
# Without Elasticsearch running, all tests pass.
# With a stale ES instance, some controller tests may error on index queries.
# To avoid this, either stop ES or reindex.
```

### Reindexing Elasticsearch

Production skips reindex on container startup for faster restarts.
Reindex manually when needed:

- After Elasticsearch index mapping changes (e.g. new searchable fields)
- After direct SQL updates or data migration (e.g. `staging:anonymize`)
- After ES volume was wiped (`docker compose down -v`)

Normal CRUD through the app does not require manual reindexing —
Searchkick auto-syncs records on save/delete.

```bash
# Inside the container (run from docker/ directory)
cd docker
docker compose exec -T rails bash -c \
  'bundle exec rails runner "ParentItem.reindex; Borrower.reindex"'
```

## Branching & Releases

Feature branches merge into `beta`. `beta` merges into `main` for production
releases. Never merge directly into `main` -- all work flows through `beta`.

```
feature-branch --> beta (prerelease) --> main (stable release)
```

Versioning is automated via semantic-release using conventional commits:
- `feat:` commits bump the minor version
- `fix:` commits bump the patch version
- `BREAKING CHANGE:` bumps the major version

When commits land on `beta`, semantic-release creates prerelease versions
(`1.0.0-beta.1`, `1.0.0-beta.2`, etc.) and tags the repo. When `beta` is
merged into `main`, a stable release is created (`1.0.0`).

The tag push triggers the Docker Build workflow, which produces versioned
Docker images:

| Branch | Version example | Docker tags |
|--------|----------------|-------------|
| `beta` | `1.0.0-beta.1` | `1.0.0-beta.1`, `beta` |
| `main` | `1.0.0` | `1.0.0`, `1.0`, `latest` |

Configuration is in `release.config.cjs`. The release workflow authenticates
using a GitHub App and requires `APP_ID` and `APP_PRIVATE_KEY` secrets in the
repository or organization settings.

## CI

Add `[skip ci]` to commit messages for docs-only, cleanup, and chore commits
that don't affect code or builds. The test, docker-build, and release jobs all
respect this.

## Common Commands

```bash
bin/rails server                    # Start Rails server
bin/dev                             # Start all services (Rails + asset watchers)
bin/rails console                   # Rails console
bin/rails test                      # Run tests
bin/rails db:prepare                # Setup database (schema:load or migrate)
bin/rails db:seed                   # Seed database
bundle exec rubocop                 # Lint Ruby code
```

## Project Structure

```
app/
  models/          # Core domain models
  controllers/     # Request handling
  views/           # ERB templates
  mailers/         # Email (stubs, not yet implemented)
  javascript/      # Stimulus controllers, bundled by esbuild
  assets/
    stylesheets/   # Sass, compiled to app/assets/builds/
    builds/        # Compiled JS and CSS output
config/
  routes.rb        # URL routing
  database.yml     # PostgreSQL config
docs/
  plans/           # Migration and feature plans (a1-d2)
  journals/        # Session journals
test/              # Minitest test suite (200 tests)
```

## Authorization Model

All data is scoped to `current_department_id` on the User. Roles:
- **Admin**: full access across all departments
- **Leader**: manage users/borrowers/items/lendings in own department, send invitations
- **Member**: manage borrowers/items/lendings in own department
- **Guest**: read-only in own department
- **Hidden**: like guest, only visible to admins

## Key Conventions

- German UI (`Ausleihe` = lending, `Entleiher` = borrower, `Gerät` = item)
- Soft deletes: Items get `status: :deleted`, Borrowers get `borrower_type: :deleted`
- Item history tracked via `ItemHistory` on save callbacks
- Elasticsearch indexes on `ParentItem` and `Borrower` (with synonym support via `elastic_synonyms.txt`)

## Issue Tracking

Issues are tracked with `git-bug`. See the git-bug skill for commands and sync rules.

### Labels

**Type labels** (one per issue):

| Label | Usage |
|-------|-------|
| `feature` | New functionality |
| `enhancement` | Improvement to existing functionality |
| `bug` | Something isn't working |
| `chore` | Maintenance, dependencies, infrastructure, tooling |
| `documentation` | Documentation work |
| `epic` | Tracking container for a group of related issues |

**Phase labels** (one per issue, matches `docs/plans/` structure):

`phase-a`, `phase-b`, `phase-c`, `phase-d`

**Work state labels** (one per issue):

| Label | Usage |
|-------|-------|
| `ready` | Actionable, no blockers |
| `in-progress` | Currently being worked on |
| `blocked` | Waiting on something (add comment explaining why) |

### Workflow

```bash
# Start of session
git bug pull
git bug bridge pull

# Claim a task
git bug bug label new <ID> in-progress

# Complete a task
git bug bug label rm <ID> in-progress
git bug bug status close <ID>

# End of session
git bug push
git bug bridge pull          # Pull first to reconcile state
git bug bridge push          # Then push new issues to GitHub
```

**Important:** `bridge push` will silently export 0 issues if you haven't done
`bridge pull` first. Always pull before push to sync bridge state.

### Identity Setup

The GitHub bridge only exports issues authored by the identity that has
`github-login` metadata matching the bridge token. All agents must use the
**Claude identity** (`cff9ab1`) for bridge sync to work.

```bash
# Verify current identity
git config git-bug.identity

# Must be: cff9ab1d2ee9741039b2a60d90cca378a5320ba753398f6f3df8d03abcebee1b
# If not, set it:
git config git-bug.identity cff9ab1d2ee9741039b2a60d90cca378a5320ba753398f6f3df8d03abcebee1b
```

**Why:** The bridge was configured with the Claude identity tagged as
`github-login: fmzbot`. git-bug's exporter silently skips issues authored by
any identity without this metadata. This is an immutable metadata limitation
in git-bug -- the tag cannot be moved to another identity via CLI.

If issues aren't syncing to GitHub (`exported 0 issues`), check the identity
first. As a fallback, use `gh issue create` to push directly to GitHub.

## Migration Plans

Plans are in `docs/plans/`, executed in order per `docs/plans/EXECUTION-ORDER.md`:

1. **Phase A (Foundation)**: pnpm migration, testing infrastructure, dependency upgrades
2. **Phase B (Infrastructure)**: containerization, error handling, Devise+Turbo, CI/CD
3. **Phase C (Features)**: background jobs + email, conduct system, GDPR
4. **Phase D (Cutover)**: data migration from v1, VPN coordination
