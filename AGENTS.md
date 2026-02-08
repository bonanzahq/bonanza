# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bonanza Redux is a Rails 7 lending management system for university departments (Werkstätten). It manages equipment lending to students/employees with role-based access control, search functionality via Elasticsearch, and email notifications.

**Core domain models:**
- **ParentItem** → **Item**: ParentItems represent equipment types (e.g., "Camera"), Items are individual units with quantity, condition, and status
- **Borrower**: Students/employees who borrow equipment (separate from User model)
- **Lending** → **LineItem**: Lendings are shopping-cart-style checkouts that progress through states (cart → borrower → confirmation → completed), containing LineItems linking to Items
- **Department**: Werkstätten that own equipment and have staff
- **User**: Staff members with department memberships and roles (admin/leader/member/guest/hidden)

**Authorization model (CanCanCan):**
- Defined in `app/models/ability.rb:1`
- Admin: Full access across all departments
- Leader: Can manage users/borrowers/items/lendings in their department, send invitations
- Member: Can manage borrowers/items/lendings in their department
- Guest: Read-only access to their department
- Hidden: Like guest but only visible to admins
- Users can have different roles in different departments via `department_memberships`

**Lending workflow:**
1. User builds cart (state: cart) by adding Items via autocomplete
2. Select/create Borrower (state: borrower)
3. Confirm details (state: confirmation)
4. Complete checkout (state: completed, lent_at timestamp set)
5. Return via `/ruecknahme` endpoint

**Search infrastructure:**
- Uses Searchkick gem with Elasticsearch 8.4
- `ParentItem.search_items()` and `Borrower.search_people()` are primary search methods
- Synonyms configured in `elastic_synonyms.txt` (must be copied to ES config)
- ES must have default template set (see README deployment section)

## Technology Stack

- **Backend**: Rails 7.0.4.2 with Ruby 3.1.2
- **Version Management**: mise (see `mise.toml`)
- **Package Manager**: pnpm (not yarn or npm)
- **Database**: PostgreSQL
- **Frontend**: Hotwire (Turbo + Stimulus), esbuild for JS, Sass for CSS
- **Search**: Searchkick + Elasticsearch 8.4
- **Authentication**: Devise with devise_invitable
- **Authorization**: CanCanCan
- **Tags**: acts-as-taggable-on
- **File uploads**: ActiveStorage

## Common Development Commands

### Setup
```bash
bin/setup                    # Install dependencies and setup database
bundle install               # Install Ruby gems
pnpm install                 # Install JS dependencies
```

### Development server
```bash
bin/dev                      # Start all services (Rails, JS watch, CSS watch) via foreman
# OR individually:
bin/rails server -p 3000     # Rails server only
pnpm build --watch           # JS bundling (esbuild)
pnpm build:css --watch       # CSS compilation (Sass)
```

### Database
```bash
bin/rails db:create          # Create databases
bin/rails db:migrate         # Run migrations
bin/rails db:seed            # Seed database
bin/rails db:schema:load     # Load schema (faster than running all migrations)
bin/rails db:reset           # Drop, create, load schema, seed
```

### Assets
```bash
pnpm build                   # Build JS with esbuild
pnpm build:css               # Compile Sass to CSS
bin/rails assets:precompile  # Precompile all assets for production
```

### Console and utilities
```bash
bin/rails console            # Rails console
bin/rails routes             # Show all routes
rake -T                      # List available rake tasks
```

### Elasticsearch (requires ES 8.4 running locally)
```bash
# Reindex all searchable models
ParentItem.reindex
Borrower.reindex
```

## Key Application Patterns

**Current user/department tracking:**
- Uses `User.current_user` thread-local set in `ApplicationController`
- Users have a `current_department_id` that determines context for abilities
- Abilities are scoped to the user's current department

**State machines:**
- Lending uses enum states: cart → borrower → confirmation → completed
- Item uses status enum: available, lent, returned, unavailable, deleted
- Item uses condition enum: flawless, flawed, broken
- Borrower uses borrower_type enum: student, employee, deleted

**Soft deletes:**
- Items with history are soft-deleted (status: deleted) rather than destroyed
- See `Item#destroy` override at `app/models/item.rb:37`

**History tracking:**
- Items create `item_histories` records on save via `after_save :create_history_record`
- TODO mentions converting this to unified history for all borrower events

**Validation patterns:**
- Borrower registration requires TOS acceptance, insurance check, ID check (students only)
- Items cannot be edited if lent (see `item_cannot_be_changed_if_lent` validation)
- Parent item accessories should not change if child items are lent (TODO item)

**Email notifications:**
- Most mailers are stubbed (empty mailers exist in `app/mailers/`)
- TODO list includes implementing confirmation, overdue, return reminder emails
- Borrower email confirmation flow exists: `borrowers#self_register` → email → `confirm_email` action

**German localization:**
- Routes use German paths (e.g., `/werkstaetten`, `/ausleihe`, `/verwaltung`)
- UI strings and validations are in German

## Deployment Notes

**Server setup (from README):**
- Use nginx + Puma (see https://github.com/puma/puma/blob/master/docs/systemd.md)
- Requires Elasticsearch 8.7 with Temurin JDK 17
- Copy `elastic_synonyms.txt` to Elasticsearch config folder
- Set Elasticsearch default template for all indices (curl command in README.md:96)
- Bundle must include x86_64-linux platform: `bundle lock --add-platform x86_64-linux`

**Asset compilation:**
- Run PurgeCSS before precompiling assets (see `purgecss.config.js`)

**Turbo Rails updates:**
- Run `rails turbo:install` after updating turbo_rails gem

## TODOs and Known Issues

See README.md for extensive TODO list including:
- Email notification system (mostly unimplemented)
- Migration strategy from old MySQL Bonanza
- GDPR compliance (auto-delete inactive borrowers)
- Warning/banning system for borrowers
- Department closure feature
- Archiving deleted items
- Item editing restrictions when lent

## Testing

No test framework currently configured in the project.

## Agent Behavior Guidelines/Rules

- Dont use yaml aliases. Keep yaml simple and human readable
- We use mise to manage versions of nodejs, ruby and pnpm