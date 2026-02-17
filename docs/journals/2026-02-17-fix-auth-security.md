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

## Tests

8 integration tests covering both bugs in `test/controllers/users_controller_test.rb`.
All existing tests (user_test, ability_test) continue to pass.
