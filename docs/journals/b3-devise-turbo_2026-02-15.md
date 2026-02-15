# B3: Devise + Turbo Compatibility

## Summary

Executed the full b3 plan: Devise forms now work correctly with Turbo, password
policy is strengthened, borrower search links navigate correctly, and all
user-reachable Devise views are styled and translated to German.

## Changes Made

1. **Borrower link fix**: Added `data-turbo-frame="_top"` to borrower name link
   in `_result_item.html.erb` so it navigates the full page instead of trying
   to replace the turbo-frame.

2. **Turbo disabled on passwords/new**: Added `data: { turbo: false }` to the
   password reset request form.

3. **Password policy**: Changed `password_length` from `6..128` to `8..128` in
   `config/initializers/devise.rb`.

4. **Styled passwords/edit**: Rewrote from unstyled English default to Bootstrap
   layout with German text, matching the sessions/new pattern.

5. **Styled registrations/new**: Same treatment - Bootstrap, German, turbo:false.

6. **Styled registrations/edit**: Used the authenticated layout pattern (from
   invitations/new) with header and user menu. Translated "Cancel my account"
   section to German.

7. **Removed dead views**: Deleted confirmations/new, unlocks/new, and their
   mailer templates since `:confirmable` and `:lockable` are not enabled.

## Key Decisions

- Used the "disable Turbo on Devise forms" approach (Option A from the plan).
  Auth forms don't benefit from Turbo and this is the simplest solution.
- `:registerable` module is enabled on User. Registration views are live even
  though users are typically invited via devise_invitable. Styled them anyway.
- Kept the "Konto loeschen" (delete account) section on the profile edit page,
  translated to German. May want to revisit whether self-deletion should be
  allowed in a staff tool.

## Tests Added

- `test/integration/devise_turbo_test.rb` - 4 tests covering turbo attributes,
  German text, and Bootstrap styling on all modified Devise views
- `test/controllers/borrowers_controller_test.rb` - test for turbo-frame="_top"
  on borrower search result links
- `test/models/user_test.rb` - password length validation tests

## Lesson Learned

Running parallel worker agents that commit to the same branch causes commit
cross-contamination. Changes from different workers get staged together. For
future parallel work: either use separate branches per worker, or only run
parallel workers for read-only/analysis tasks and commit sequentially.
