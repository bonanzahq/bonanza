# Fix Department Closing Unexpectedly

## Branch: fix-department-closing

## Task
Investigate and fix git-bug cd3da55 - departments switching to "voruebergehend geschlossen" without user intent.

## Root Cause
The `staff` and `unstaff` actions in `DepartmentsController` used GET routes (`get 'schliessen'`, `get 'besetzen'`). Turbo Drive prefetches GET links on hover by default in Rails 8. Mousing over "Werkstatt voruebergehend schliessen" fired the GET request and closed the department without a click.

## Fix
1. Changed routes from `get` to `patch` in `config/routes.rb`
2. Changed `link_to` to `button_to` with `method: :patch` in two views (`borrowers/index.html.erb`, `layouts/_unstaffed_message.html.erb`)
3. Fixed bonus bug: single-quoted strings with `#{}` in flash messages weren't interpolating

## Tests
Created `test/controllers/departments_controller_test.rb` with 6 tests:
- Member can staff/unstaff their department
- Guest cannot staff/unstaff (redirects to `public_home_page_path`, not `root_path` -- guests use a different redirect in the CanCan AccessDenied handler)
- State changes persisted correctly (assert_changes)

## Observations
- The CanCan AccessDenied handler in ApplicationController redirects guests to `public_home_page_path` (`/home`), members/leaders/admins to `root_path`. Initial test assertion used `root_path` which was wrong for guests.
- `button_to` generates a `<form>` with CSRF token. Used `form_class` param for inline styling (`inline-button-form` in borrowers index, `d-inline` in unstaffed banner).

## PR
https://github.com/bonanzahq/bonanza/pull/105 (targeting main, not merged)
