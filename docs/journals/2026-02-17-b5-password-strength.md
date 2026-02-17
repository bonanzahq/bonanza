# Session: Staging troubleshooting + Password strength (b5)

## Staging deployment follow-up

- Diagnosed login failure on staging (bonanza2.fh-potsdam.de): POST /login returning 422
- Root cause: `db:prepare` runs `db:seed` on fresh database, which created hardcoded admin (`admin@example.com` / `password`) before `bootstrap:admin` could create the real admin from env vars
- Fix: added `return if Rails.env.production?` guard to `db/seeds.rb` (PR #90, merged)
- Verified login works with correct credentials after manual user update on server
- Email delivery works, landed in junk (sender is `bonanza@fh-potsdam.de`, SPF/DKIM is FHP IT's domain)

## Issues filed from staging observations

- Department switching: no UI for users in multiple departments (0cb7ace)
- Item-department binding: unclear how items are assigned (8e69ffb)
- Role permissions discussion for Mitarbeitende (03079a7)
- Verwaltung link hidden from members - wrong `can? :manage` check, should be `can? :update` (7147963)
- SQL injection in ParentItemsController (ec6153b) - low severity, all values come from controller not user input
- Warn users with weak passwords on login / nagware (3153ad6)
- Extract ~204 hardcoded German strings into locale files (54ba6a7)

## Password strength validation (b5)

Implemented in PR #101 on branch `b5-password-strength`:

- Added `zxcvbn` (1.0.0) for entropy scoring and `unpwn` (1.0.1) for breach detection
- Custom `PasswordStrengthValidator` (ActiveModel validator)
- Minimum password length raised from 8 to 12 characters
- Minimum zxcvbn score: 3 (safely unguessable, ~10^8 guesses)
- Context-aware: penalizes passwords containing user's email, name, or "bonanza"
- Graceful degradation: network failures in breach check don't block users
- German error messages in locale files
- Password hint text consolidated into single `t('password_hint')` locale key
- All test/seed passwords changed to memorable `platypus-umbrella-cactus`
- Fixed German validation error message ("Fehler verhinderten das Speichern von benutzer" had wrong capitalization and declension)

### Copilot review findings

- Requesting Copilot review via API doesn't work reliably; must use GitHub UI
- `@copilot` mention in PR comment triggers the coding agent (creates sub-PR), not the reviewer
- The actual review UI button works and produces useful feedback

### Pre-existing test failures found

- `LendingControllerTest#test_index_returns_200` and `BorrowersControllerTest#test_index_returns_200` fail with 500 errors - not caused by our changes, existed before

## Decisions made

- Password length: 12 chars minimum
- Use `unpwn` (no external API dependency, local bloom filter)
- zxcvbn score threshold: 3
- Enforce only on password change, not retroactively
- Client-side strength meter deferred to separate task
- Test password: `platypus-umbrella-cactus` (memorable, zxcvbn score 4, not breached)

## Open items for next session

- PR #101 awaiting merge
- PR #102 (Copilot coding agent sub-PR) should be closed - it's empty noise
- `fix-seeds-production-guard` worktree can be cleaned up (PR #90 merged)
- Pre-existing controller test failures need investigation
- i18n extraction is a large tech debt item (plan at docs/plans/i18n-extraction.md)
- Next on roadmap: c1+c2 (background jobs + email notifications)
