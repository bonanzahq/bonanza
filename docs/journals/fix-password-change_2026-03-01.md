# Fix Password Change - Session Journal

## Branch: fix-password-change
## PR: #187

## Summary

Fixed a security vulnerability where users could change their password without
verifying their current password. Also improved error display styling.

## What was done

### Security fix: require current password for self-edit

- Added "Aktuelles Passwort" field to the password accordion in the user edit
  form (`app/views/users/_form.html.erb`)
- Added validation in `UsersController#update` that checks the current password
  via Devise's `valid_password?` before allowing password changes
- Only applies to self-edits (`@user == current_user`) — admins/leaders cannot
  set other users' passwords directly (they use password reset emails instead)
- Non-password profile updates (name, email) are unaffected
- Added German error message in `config/locales/bonanza.de.yml`

### Error display fix

- Replaced the plain `#error_explanation` div in the users form with the shared
  `_form_errors` partial, which uses Bootstrap `alert-danger` (red) styling
- Consistent with error display in other forms throughout the app

### Key decisions

- Moved the current_password check **before** the `respond_to` block in the
  controller. Initial approach used `next` inside `respond_to`, but this caused
  issues because `respond_to` collects format handlers in the block and
  dispatches after — `next` exited before dispatch, and `return` exited the
  entire method before dispatch (resulting in 204 No Content).
- Used `params.dig(:user, :current_password)` instead of
  `params[:user].delete(:current_password)` to avoid mutating params in the
  update action. The defensive `delete` in `user_params` handles stripping.
- The HANDOFF.md incorrectly stated that admins/leaders can set other users'
  passwords directly. Code review confirmed this is not the case — the form
  shows a "Passwort-Reset E-Mail senden" button instead, and `user_params`
  strips password fields when `@user != current_user`.

### Tests

- Updated existing test to include `current_password`
- Added 3 new controller tests (missing current password, wrong current
  password, non-password update)
- Fixed `WeakPasswordWarningTest` (merged from main after branch creation)
  to include `current_password` in its password change flow
- All 618 tests pass

### E2E verification

- Red error alert displays for missing/wrong current password
- Successful password change with correct current password
- New password works for login, old password rejected
- Password change notification email sent via Devise
- Admin password reset email flow still works

## Files changed

- `app/controllers/users_controller.rb` — current_password validation
- `app/views/users/_form.html.erb` — current_password field + shared error partial
- `config/locales/bonanza.de.yml` — German error message
- `test/controllers/users_controller_test.rb` — new and updated tests
- `test/integration/weak_password_warning_test.rb` — added current_password

## Copilot review

Copilot flagged the `next`/`return` inside `respond_to` and suggested
`params.dig` + `return`. We adopted `params.dig` but moved the check outside
`respond_to` entirely, which was the actual fix for the 204 bug.
