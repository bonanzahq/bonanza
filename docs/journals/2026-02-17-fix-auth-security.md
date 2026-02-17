# fix-auth-security

Branch: `fix-auth-security` | PR: #107

## What we did

Fixed two auth/security bugs and polished the UI based on Fabian's review.

### Bug 1: Disabled Devise user registration route (git-bug 26e2785, closed)

- Removed `:registerable` from User model's devise modules
- Cleaned up `registration`/`sign_up` path_names from routes
- Users can only be created via `devise_invitable` now
- `/registrieren` (borrower self-registration) is unaffected

### Bug 2: Password changes restricted to self-edit (git-bug b353737, closed)

- `user_params` only permits `:password`/`:password_confirmation` when `@user == current_user`
- Also restricted `:admin` param to admin users only (was permitted for everyone)
- Added `send_password_reset` controller action for admins/leaders to trigger Devise reset emails
- Added CanCanCan ability for leaders (scoped to same department, non-admin, not self)
- Updated form: password fields for self-edit, reset link for others

### UI fixes from browser testing

- **Nested form bug**: `button_to` generates a `<form>`, which was invalid inside
  the existing `form_with`. Replaced with `link_to` + `data-turbo-method: :post`
  and `data-turbo: true` to override the parent form's `turbo: false`.
- **Reset button positioning**: Initially placed after the form in `edit.html.erb`,
  which put it below "Speichern". Moved back into `_form.html.erb` using `link_to`.
- **Accordion height**: Added `.accordion-compact` CSS class to match `form-select`
  padding (`.375rem .75rem`) and chevron size (`.75rem`).

## Issues discovered during testing

- **Borrower self-registration 500 error** (git-bug 96a1dd9, open): Pre-existing
  bug on `main`. `send_confirmation_pending_email` raises `ActiveRecord::Rollback`
  outside a transaction block when mail delivery fails. The rollback has no effect
  and propagates as a 500. The actual exception is swallowed without logging.
- **Unstyled Devise emails**: Already tracked as git-bug 08c505b.

## Tests

8 integration tests in `test/controllers/users_controller_test.rb`:
- Registration routes return routing error (2 tests)
- User can change own password
- Admin cannot set another user's password
- Leader cannot set another user's password
- Admin can trigger password reset for another user
- Leader can trigger password reset for same-department user
- Member cannot trigger password reset

All existing tests (user_test, ability_test) unaffected.

## Files changed

- `app/models/user.rb` - removed `:registerable`
- `app/models/ability.rb` - added `:send_password_reset` for leaders
- `app/controllers/users_controller.rb` - restricted `user_params`, added `send_password_reset` action
- `config/routes.rb` - removed registration path_names, added `send_password_reset` member route
- `app/views/users/_form.html.erb` - conditional password UI, compact accordion class
- `app/views/users/edit.html.erb` - no net changes (intermediate fix reverted)
- `app/assets/stylesheets/application.sass.scss` - `.accordion-compact` styles
- `test/controllers/users_controller_test.rb` - new test file
