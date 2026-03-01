# Department Switching

Branch: `department-switching`
PR: #178

## What was done

### Department Switcher UI
- Added `User#switchable_departments` method — returns departments with active
  (non-deleted) membership, excluding current, with `.distinct.order(:name)`
- Added `PATCH /switch_department` route and `UsersController#switch_department`
  action — validates membership via `.exists?`, updates `current_department_id`,
  destroys lending cart (guarded by session check), redirects to root
- Created `_department_switcher.html.erb` partial — Bootstrap dropdown for
  multi-department users, plain `<span>` for single-department users
- Integrated into `application.html.erb` logo/header area

### Move Item Between Departments
- Added `:move` ability in `ability.rb` for admins, leaders, and members
- Department select field integrated into the main edit form (`_form.html.erb`)
  — only shown when user `can?(:move)` and has multiple departments
- Items with active lendings show a disabled select with explanation message
- `ParentItemsController#update` handles department changes: validates target
  membership via single SQL query, checks `has_lent_items?`, updates department,
  reindexes Elasticsearch, tags via the correct (target) department
- After move, redirects to `borrowers_path` with flash notice (avoids 301
  redirect through `/artikel` which caused Turbo to swallow the flash)

### Tests
- Model tests: `switchable_departments`, `has_lent_items?`
- Ability tests: `:move` permission across admin, leader, member, guest
- Controller tests: `switch_department` (valid/invalid/deleted membership),
  `update` with department change (happy path, lent items, unauthorized, guest)
- Integration tests: switcher visibility for multi/single-department users

### Copilot Review Fixes
Addressed all 8 review comments:
1. N+1 in target dept lookup → single SQL query
2. Extra blank lines → removed
3. Missing `.distinct.order(:name)` on `switchable_departments` → added
4. Double query in switcher partial → cached in local variable
5. N+1 in form department list → direct `Department.joins(...)` query
6. `current_lending.destroy` creating then destroying → session guard
7. `.pluck(:id).include?` → `.exists?(id:)`
8. Tags bound to source dept after move → tag via item's new department

### E2E Testing
Full browser-based E2E testing confirmed:
- Single-dept users see plain text, multi-dept users see dropdown
- Switching scopes all content (items, lendings, borrowers)
- Move via edit form works, flash message displays
- Lent items show disabled select with explanation
- Guests have no access to edit/move

## Issues Closed
- `0cb7ace` (#94): Department switching UI
- `8e69ffb` (#92): Item-department binding

## Evolution During Session
The move UI went through three iterations based on Fabian's feedback:
1. Started as a separate form on the show page
2. Moved to a separate form on the edit page
3. Integrated as a `<select>` field inside the main edit form

The old standalone `move` action and route were removed after integration.

## Test Suite
575 runs, 1095 assertions, 0 failures, 0 errors
