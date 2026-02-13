# Bonanza

Equipment lending management system for FH Potsdam. Rewrite of Bonanza v1.

## Tech Stack

- **Language**: Ruby 3.4.8 (upgraded from 3.1.2, see `docs/plans/a2_dependency-updates.md`)
- **Framework**: Rails 7.0.4.3 (EOL -- upgrade to 7.2 then 8.x in progress)
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
cd ~/Documents/bonanzahq/bonanza/<worktree>

# Start all services (builds image if needed)
docker compose up -d

# The entrypoint automatically:
#   1. Waits for PostgreSQL and Elasticsearch
#   2. Runs db:prepare (schema:load on fresh DB, migrate on existing)
#   3. Seeds the database
#   4. Reindexes Elasticsearch
#   5. Starts Rails with foreman (web + js + css watchers)
```

The app is available at `http://localhost:3000`. Caddy reverse proxy is on
port 80/443. Mailpit UI is at `http://localhost:8025`.

Default seed credentials: `admin@example.com` / `password`

If the database or ES get into a bad state, nuke everything and restart:

```bash
docker compose down -v    # -v removes volumes (DB data, ES data)
docker compose up -d      # Fresh start
```

**Important:** `db/schema.rb` defines all tables. There are no migration files.
If schema.rb gets emptied (e.g. by running `db:schema:dump` against an empty
database), restore it with `git checkout -- db/schema.rb`.

### Running tests locally

Tests run outside Docker but need a PostgreSQL instance. Use the Docker DB:

```bash
# Build assets first (required for controller tests)
pnpm install --frozen-lockfile
pnpm build && pnpm build:css

# Run tests (mise picks up Ruby from mise.toml)
mise exec -- env TEST_DATABASE_PASSWORD=password bin/rails test

# Without Elasticsearch running, all 200 tests pass.
# With a stale ES instance, 2 controller tests may error on index queries.
# To avoid this, either stop ES or reindex.
```

### Reindexing Elasticsearch

```bash
# Inside the container
docker compose exec -T rails bash -c \
  'bundle exec rails runner "ParentItem.reindex; Borrower.reindex"'
```

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
test/              # Minitest (framework not yet configured)
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

Issues are tracked with `git-bug`, a distributed issue tracker embedded in git.
Issues sync bidirectionally to GitHub Issues via the configured bridge.

Use the `git-bug` skill (invoke with `/git-bug`) for the full command reference.

### Quick Reference

```bash
git bug bug                          # List open issues
git bug bug new --non-interactive -t "Title" -m "Description"
git bug bug show <ID>                # Show issue details
git bug bug status close <ID>        # Close an issue
git bug bug label new <ID> <label>   # Add a label
git bug bug label rm <ID> <label>    # Remove a label
git bug push                         # Push issues to git remote
git bug bridge push                  # Sync issues to GitHub Issues
```

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
