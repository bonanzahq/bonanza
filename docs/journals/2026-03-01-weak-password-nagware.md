# Weak Password Nagware

Branch: `weak-password-nagware`
PR: #185 (https://github.com/bonanzahq/bonanza/pull/185)
git-bug: `3153ad6` (closed), GitHub #100

## What We Did

Implemented a post-login warning system for users with weak passwords.
On sign-in, the submitted password is checked against zxcvbn scoring
(reusing the existing `PasswordStrengthValidator`). If weak (score < 3),
a session flag is set and a persistent Bootstrap alert banner renders on
every page until the user changes their password.

## Implementation

- **`PasswordStrengthValidator`**: Extracted `self.weak?` and
  `self.user_inputs_for` class methods so the scoring logic can be
  called from the Warden hook without instantiating a validator.
  Instance `user_inputs` delegates to the class method.

- **Warden `after_authentication` callback** (in `devise.rb`):
  Checks the password param on every authentication. Only acts when
  a password param is present (skips remember-me cookie re-auth).
  Sets or clears `session[:weak_password]`.

- **Banner partial** (`shared/_weak_password_warning.html.erb`):
  Non-dismissible `alert-warning` strip, full-width, positioned
  between the green dev bar and the logo. German text with link
  to profile edit page.

- **Layout**: Renders banner when `user_signed_in? && session[:weak_password]`.
  Adds `weak-password` body class for CSS logo offset.

- **CSS**: Added `#logo` top offsets for `.weak-password` combined
  with `.is-admin` and `.unstaffed` (follows existing pattern).

- **Session cleanup**: `UsersController#update` clears the flag only
  when `@user.saved_change_to_encrypted_password?` is true.

- **Locale**: German strings in `de.yml`.

## Design Decisions

- **Session-only, no DB**: The plaintext password is only available at
  sign-in time. Storing a flag in the session avoids persisting anything
  about password quality in the database.

- **No dismiss button**: Nagware should nag. The banner persists until
  the password is actually changed. Considered cookie-based 72h dismiss
  but decided YAGNI.

- **No breach check at login**: The validator's `check_breach` calls an
  external API (unpwn). Too slow and unreliable for the login path.
  zxcvbn score alone is sufficient for the warning.

## Review Fixes

1. **Rack params use string keys** — Changed `dig(:user, :password)` to
   `dig("user", "password")`. Copilot caught this.

2. **Session cleared on any update** — Guarded with
   `saved_change_to_encrypted_password?` so name/email changes don't
   clear the banner. Copilot caught this.

3. **Remember-me clears banner** — The `else` branch ran when no
   password param was present (cookie re-auth), clearing the flag.
   Restructured to only act when password param exists. Internal
   review caught this.

4. **Layout guard** — Added `user_signed_in?` to the banner render
   condition for safety. Internal review caught this.

5. **Banner positioning** — Initial placement overlapped the
   absolute-positioned logo. Iterated through three layout fixes:
   full-width strip, moved above logo in DOM, added CSS offsets.

## Tests

16 tests total (6 integration + 10 validator unit):
- Banner shown for weak password
- No banner for strong password
- Banner links to profile edit
- Banner persists across navigation
- Banner cleared after password change
- Banner cleared after re-login with strong password
- `weak?` class method: weak/strong/blank inputs

## Known Limitations

- Admin changing another user's password doesn't clear that user's
  session flag (inherent to session-based state; clears on next login)
- No English translation (app is German-only)
- CSS logo offsets are combinatorial (matches existing pattern)
