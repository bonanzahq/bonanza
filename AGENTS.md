# Bonanza Redux

Equipment lending management system for FH Potsdam. Rewrite of Bonanza v1.

## Tech Stack

- **Language**: Ruby 3.1.2 (EOL -- upgrade to 3.4+ planned, see `docs/plans/a2_dependency-updates.md`)
- **Framework**: Rails 7.0.4.2 (EOL -- upgrade to 8.x planned)
- **Database**: PostgreSQL 15
- **Search**: Elasticsearch 8.4 via Searchkick
- **Frontend**: Hotwire (Turbo + Stimulus), esbuild, Sass
- **Auth**: Devise + devise_invitable, CanCanCan for authorization
- **Package Manager**: pnpm (migration from yarn in progress, see `docs/plans/a1_yarn-to-pnpm.md`)
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

## Common Commands

```bash
bin/rails server                    # Start Rails server
bin/dev                             # Start all services (Rails + asset watchers)
bin/rails console                   # Rails console
bin/rails test                      # Run tests
bin/rails db:migrate                # Run migrations
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

## Migration Plans

Plans are in `docs/plans/`, executed in order per `docs/plans/EXECUTION-ORDER.md`:

1. **Phase A (Foundation)**: pnpm migration, testing infrastructure, dependency upgrades
2. **Phase B (Infrastructure)**: containerization, error handling, Devise+Turbo, CI/CD
3. **Phase C (Features)**: background jobs + email, conduct system, GDPR
4. **Phase D (Cutover)**: data migration from v1, VPN coordination
