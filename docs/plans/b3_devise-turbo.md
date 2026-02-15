# B3: Devise + Turbo Compatibility

## Problem Statement

Devise forms have inconsistent Turbo handling. Some forms disable Turbo,
others don't. Several views are unstyled default Devise templates (English).
Password policy is too weak. Related bugs need fixing.

## Related Issues

- `d97da50` - Execute b3: Devise + Turbo compatibility
- `b38946c` - Devise allows weak passwords
- `3886815` - Borrower link shows 'Content missing' due to Turbo Frame mismatch

## Current State (from audit)

### Devise Config
- Devise 5.0.1, devise_invitable 2.0.11
- Turbo error/redirect status already configured correctly:
  - `config.responder.error_status = :unprocessable_entity`
  - `config.responder.redirect_status = :see_other`
- `navigational_formats` is commented out (using defaults)
- `password_length = 6..128` (too weak, should be 8+ minimum)

### Forms with `data-turbo="false"` (correct)
- `sessions/new.html.erb` -- sign in
- `invitations/new.html.erb` -- invite user
- `invitations/edit.html.erb` -- accept invitation

### Forms WITHOUT `data-turbo="false"` (need fixing)
- `passwords/new.html.erb` -- request password reset
- `passwords/edit.html.erb` -- change password (also unstyled, English)
- `registrations/new.html.erb` -- sign up (unstyled, English)
- `registrations/edit.html.erb` -- edit profile (unstyled, English)
- `confirmations/new.html.erb` -- resend confirmation (unstyled, English)
- `unlocks/new.html.erb` -- resend unlock (unstyled, English)

### Turbo Frame mismatch
- `app/views/borrowers/_result_item.html.erb` line 4: borrower name link
  is inside `<turbo-frame id="results">`. Clicking navigates inside the
  frame, but the target page has no matching frame. Fix: add
  `data-turbo-frame="_top"` to the link.

### Custom controllers
- `app/controllers/users/invitations_controller.rb` -- handles invite
  creation and admin deletion. No Turbo issues.

### Views that are styled and German
- `sessions/new.html.erb` (sign in)
- `passwords/new.html.erb` (password reset request)
- `invitations/new.html.erb` (invite user)
- `invitations/edit.html.erb` (accept invitation)

### Views that are unstyled Devise defaults (English)
- `passwords/edit.html.erb`
- `registrations/new.html.erb`
- `registrations/edit.html.erb`
- `confirmations/new.html.erb`
- `unlocks/new.html.erb`

## Implementation Plan

### Step 1: Add `data-turbo="false"` to all Devise forms

Add `data: { turbo: false }` to every Devise form_for that doesn't have it.
This is the simple, reliable approach -- auth forms don't benefit from Turbo.

Files to change:
- `app/views/devise/passwords/new.html.erb`
- `app/views/devise/passwords/edit.html.erb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/registrations/edit.html.erb`
- `app/views/devise/confirmations/new.html.erb`
- `app/views/devise/unlocks/new.html.erb`

### Step 2: Strengthen password policy

In `config/initializers/devise.rb`:
```ruby
config.password_length = 8..128
```

Update `app/views/devise/invitations/edit.html.erb` -- the `minlength: "8"`
on the password field is already correct but hardcoded. Leave it as-is since
it matches the new config value.

### Step 3: Fix Turbo Frame mismatch on borrower links

In `app/views/borrowers/_result_item.html.erb`, add `data-turbo-frame="_top"`
to the borrower name link so it navigates the full page instead of trying to
replace the turbo-frame:

```erb
<%= link_to borrower_path(borrower), class: "name", data: { turbo_frame: "_top" } do %>
```

### Step 4: Style unstyled Devise views

The unstyled views (`passwords/edit`, `registrations/new`,
`registrations/edit`, `confirmations/new`, `unlocks/new`) use default Devise
scaffold HTML with no Bootstrap classes and English text. Style them to match
the existing styled views (sessions/new, passwords/new, invitations/*):

- Use the same `row justify-content-center` / `col-6` / `bg-light p-3 rounded`
  layout pattern
- Use Bootstrap `form-control`, `form-label`, `btn btn-primary` classes
- Translate all text to German
- Add "Zur Startseite" back link where appropriate

**Note:** Only style views that users can actually reach. Check which Devise
modules are enabled on the User model to determine which views are active.
Registration may be disabled (users are invited via devise_invitable).

## Files to Modify

| File | Change |
|------|--------|
| `config/initializers/devise.rb` | `password_length = 8..128` |
| `app/views/devise/passwords/new.html.erb` | Add `data-turbo="false"` |
| `app/views/devise/passwords/edit.html.erb` | Add turbo:false, style, translate |
| `app/views/devise/registrations/new.html.erb` | Add turbo:false, style, translate (if reachable) |
| `app/views/devise/registrations/edit.html.erb` | Add turbo:false, style, translate (if reachable) |
| `app/views/devise/confirmations/new.html.erb` | Add turbo:false, style, translate (if reachable) |
| `app/views/devise/unlocks/new.html.erb` | Add turbo:false, style, translate (if reachable) |
| `app/views/borrowers/_result_item.html.erb` | Add `data-turbo-frame="_top"` to link |

## Testing

1. Run existing test suite -- must stay green
2. Write integration tests for Devise flows:
   - Sign in succeeds and redirects
   - Sign in with wrong password shows error
   - Password reset request works
   - Sign out works
3. Write test for borrower link navigation (no Turbo Frame mismatch)
4. Test password minimum length validation (8 chars)

## Verification

- [ ] All existing tests pass
- [ ] All Devise forms have `data-turbo="false"`
- [ ] Password minimum length is 8
- [ ] Borrower link in search results navigates correctly
- [ ] All user-reachable Devise views are styled and in German
