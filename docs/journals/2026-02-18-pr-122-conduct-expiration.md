# PR #122: Conduct Model

Branch: `feat/conduct-expiration`
PR: https://github.com/bonanzahq/bonanza/pull/122
Merged: 2026-02-18

## Summary

Implements business logic on the `Conduct` model for expiration, warning escalation to automatic bans, and conduct cleanup. Adds instance methods for querying expiration state and a FactoryBot factory for use in tests.

## What changed

| File | Change |
|------|--------|
| `app/models/conduct.rb` | Added `self.remove_expired`, `self.check_warning_escalation`, `expired?`, `days_remaining`, `expiration_date`, `automatic?` methods; added `after_commit :reindex_borrower` callback; added `user_added_duration_or_perma?` custom validation |
| `test/models/conduct_test.rb` | New test file — 26 tests covering enum values, validations, `expired?`, `days_remaining`, `expiration_date`, `automatic?`, `remove_expired`, and `check_warning_escalation` |
| `test/factories/conducts.rb` | New FactoryBot factory with traits: `:banned`, `:with_duration`, `:automatic`, `:expired` |

## Why

Conducts (warnings and bans) must expire automatically once their duration elapses to avoid permanently penalising borrowers. Automatic bans triggered by repeated warnings also need a cleanup path. The `remove_expired` class method is designed to be called from a scheduled job. `check_warning_escalation` encapsulates the rule that two warnings in the same department trigger an automatic 30-day ban, preventing duplicate bans if called more than once. Reindexing the borrower on conduct changes keeps the Elasticsearch `conducts` field accurate for search filtering.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/models/conduct_test.rb` | `kind enum has expected values` | Enum maps `warned` → 0, `banned` → 1 |
| | `factory creates a valid conduct` | FactoryBot default factory is valid and persists |
| | `requires reason` | Conduct without reason is invalid |
| | `requires borrower` | Conduct without borrower is invalid |
| | `requires department` | Conduct without department is invalid |
| | `duration must be integer when present` | Fractional duration is invalid |
| | `duration allows nil` | Nil duration is valid when permanent is true |
| | `non-permanent conduct with no duration is invalid when user present` | Custom validation rejects non-permanent conduct with no duration when a user is set |
| | `non-permanent conduct with positive duration is valid` | Positive integer duration with `permanent: false` is valid |
| | `permanent conduct without duration is valid` | `permanent: true` with no duration is valid |
| | `conduct without lending is valid` | `lending` association is optional |
| | `expired? returns true when duration has passed` | Returns true for a conduct created 2 days ago with 1-day duration |
| | `expired? returns false when still valid` | Returns false for a 14-day conduct just created |
| | `expired? returns false for permanent conduct` | Returns false regardless of created_at when permanent |
| | `expired? returns false when no duration` | Returns false for automatic conducts with nil duration |
| | `days_remaining returns correct value` | Within ±1 day of 14 for a fresh 14-day conduct |
| | `days_remaining returns nil for permanent` | Returns nil when conduct is permanent |
| | `days_remaining returns 0 when expired` | Returns 0 (not negative) for an expired conduct |
| | `expiration_date returns correct date` | Returns `created_at + 14 days` as a Date |
| | `expiration_date returns nil for permanent` | Returns nil when conduct is permanent |
| | `automatic? returns true when user_id is nil` | Returns true for conducts with no associated user |
| | `automatic? returns false when user is present` | Returns false when a user is associated |
| | `remove_expired destroys expired conducts with duration` | Destroys the expired one, leaves the valid one |
| | `remove_expired destroys stale automatic conducts` | Destroys automatic conducts older than 60 days |
| | `remove_expired does not destroy permanent conducts` | Permanent conducts survive `remove_expired` |
| | `check_warning_escalation creates ban after 2 warnings` | Creates an automatic 30-day ban when ≥ 2 warnings exist with no current ban |
| | `check_warning_escalation does not create duplicate ban` | Returns nil and skips creation if a ban already exists |
| | `check_warning_escalation returns nil for fewer than 2 warnings` | Returns nil when only one warning exists |

## Manual verification

Run the conduct model tests:

```bash
docker compose exec rails bundle exec rails test test/models/conduct_test.rb
```

Test expiration logic from the Rails console:

```bash
docker compose exec rails bundle exec rails console
# In the console:
# Find or create an expired conduct
conduct = Conduct.where(permanent: false).where.not(duration: nil).first
puts conduct.expired?
puts conduct.days_remaining
puts conduct.expiration_date

# Trigger cleanup
removed = Conduct.remove_expired
puts "Removed #{removed.size} expired conducts"

# Test warning escalation
borrower = Borrower.first
department = Department.first
Conduct.check_warning_escalation(borrower, department)
```
