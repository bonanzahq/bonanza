# fix-auth-security

## Summary

Fixed two auth/security bugs on branch `fix-auth-security`.

## Bug 1: Devise registration route disabled

- Removed `:registerable` from User model's devise modules
- Cleaned up `registration`/`sign_up` path_names from routes
- Users can only be created via `devise_invitable` now
- The `/registrieren` borrower self-registration route is unaffected

## Bug 2: Password changes restricted to self-edit

- `user_params` now only permits `:password`/`:password_confirmation` when `@user == current_user`
- Added `send_password_reset` controller action for admins/leaders to trigger Devise password reset emails
- Added CanCanCan ability for leaders (scoped to same department, non-admin, not self)
- Updated form to show password fields only for self-edit, reset button for others
- Also restricted `:admin` param to admin users only (was previously permitted for everyone)

## Browser Testing

Found and fixed a nested form issue during browser testing: `button_to` generates
a `<form>` element which can't be nested inside `form_with`. Moved the password
reset button from `_form.html.erb` to `edit.html.erb` (after the form partial).

Verified in browser:
- `/register/register` returns routing error (Bug 1)
- `/registrieren` (borrower self-registration) still works
- Editing another user: no password fields, reset button sends email to Mailpit
- Editing own profile: password accordion with password fields, no reset button

## Tests

8 integration tests covering both bugs in `test/controllers/users_controller_test.rb`.
All existing tests (user_test, ability_test) continue to pass.
