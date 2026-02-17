# Fix Department Closing Unexpectedly

## Branch: fix-department-closing
## PR: https://github.com/bonanzahq/bonanza/pull/105

## Task
Investigate and fix git-bug cd3da55 - departments switching to "voruebergehend geschlossen" without user intent.

## Root Cause
The `staff` and `unstaff` actions in `DepartmentsController` used GET routes (`get 'schliessen'`, `get 'besetzen'`). Turbo Drive prefetches GET links on hover and replays them on back/forward navigation. Any of these actions could close the department without an intentional click.

## Fix
1. Changed routes from `get` to `patch` in `config/routes.rb`
2. Changed `link_to` to use `data: { turbo_method: :patch }` in two views (`borrowers/index.html.erb`, `layouts/_unstaffed_message.html.erb`). Initially used `button_to` but it broke the visual styling of the management link grid - switched to `link_to` with `data-turbo-method` which keeps the same `<a>` tag appearance while making Turbo send PATCH.
3. Fixed string interpolation bug in flash messages (single quotes -> double quotes)

## Tests
Created `test/controllers/departments_controller_test.rb` with 6 tests:
- Member can staff/unstaff their department
- Guest cannot staff/unstaff (redirects to `public_home_page_path`, not `root_path`)
- State changes persisted correctly (assert_changes)

## Additional Findings

### Broken admin checkbox for staffed (filed as git-bug e5e3938)
The custom `staffed=` setter compares with `== true` / `== false` but Rails form params are strings ("0"/"1"). The admin checkbox in the edit form can never change the staffed value.

### Pre-existing bugs filed
- **8800852** - FOUC when using cancel button on department edit form (`link_to :back` + Turbo Drive conflict)
- **838d46a** - JS SyntaxError on page load (`<anonymous code>:49:24`)
- **14257e4** - Extra closing `</div>` in application layout

## Decisions
- Used `link_to` with `data-turbo-method: :patch` instead of `button_to` because `button_to` generates a `<form>` with a `<button>` that doesn't match the surrounding link grid styling
- Turbo automatically includes CSRF tokens from the `<meta>` tag for non-GET requests, so `data-turbo-method` is safe without an explicit form
- Updated seed password in AGENTS.md (`platypus-umbrella-cactus`, not `password`)

## Status
- git-bug cd3da55 closed (verified by Fabian)
- PR ready for merge
