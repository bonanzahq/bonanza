# PR #125: Conduct Email Wiring

Branch: `feat/conduct-email-wiring`
PR: https://github.com/bonanzahq/bonanza/pull/125
Status: Open

## Summary

Wires transactional email delivery into the conduct lifecycle: banning a borrower via `BorrowersController#add_conduct` now enqueues `ban_notification_email`; removing a ban via `remove_conduct` enqueues `ban_lifted_notification_email`. The `Conduct` model gains `remove_expired`, `check_warning_escalation`, `expired?`, `days_remaining`, `expiration_date`, and `automatic?` methods; an `after_create_commit` callback triggers escalation and sends `auto_ban_notification_email` when two warnings accumulate. The borrower detail partial is updated to display remaining days and expiration dates for conducts.

## What changed

| File | Change |
|------|--------|
| `app/controllers/borrowers_controller.rb` | `add_conduct` enqueues `BorrowerMailer.ban_notification_email` on `:critical` queue after a successful save; `remove_conduct` enqueues `BorrowerMailer.ban_lifted_notification_email` on `:default` queue after a successful destroy |
| `app/models/conduct.rb` | Added `remove_expired` class method (destroys conducts past duration or stale automatics); `check_warning_escalation` class method (auto-bans after 2 warnings); `expired?`, `days_remaining`, `expiration_date`, `automatic?` instance methods; `after_create_commit :notify_and_escalate` callback; `reindex_borrower` callback on create/update/destroy |
| `app/views/borrowers/_borrower.html.erb` | Displays `days_remaining` and `expiration_date` for bans and warnings; render logic now uses `conduct.expired?`, `conduct.permanent?`, and `conduct.expiration_date` |
| `test/controllers/borrowers_controller_conduct_test.rb` | New — 6 integration tests covering ban email enqueuing, invalid conduct (no email), ban-lift email, cross-department guard, second-warning escalation email, and first-warning (no email) |
| `test/models/conduct_test.rb` | Extended with tests for `expired?`, `days_remaining`, `expiration_date`, `automatic?`, `remove_expired`, and `check_warning_escalation` |

## Why

Borrowers previously received no notification when banned or when a ban was lifted, despite the mailer methods existing. The warning escalation logic (auto-ban after 2 warnings) also had no email path. This PR closes those gaps and adds the underlying conduct business-logic methods needed to display accurate expiry information in the UI.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/controllers/borrowers_controller_conduct_test.rb` | `add_conduct enqueues ban_notification_email` | POST to `borrower_add_conduct_path` with valid params enqueues exactly 1 email |
| | `add_conduct does not enqueue email when conduct is invalid` | POST with blank reason and no duration enqueues 0 emails |
| | `remove_conduct enqueues ban_lifted_notification_email` | GET to `borrower_remove_conduct_path` with own-department conduct enqueues 1 email |
| | `remove_conduct does not enqueue email for conduct from different department` | Conduct belonging to another department is not destroyed and enqueues 0 emails |
| | `creating second warning triggers escalation and enqueues auto_ban_notification_email` | Second `warned` conduct triggers `notify_and_escalate`, which enqueues `auto_ban_notification_email` via `BorrowerMailer` |
| | `creating first warning does not enqueue auto_ban_notification_email` | Single warning does not trigger escalation |
| `test/models/conduct_test.rb` | `kind enum has expected values` | `Conduct.kinds` returns `{"warned"=>0, "banned"=>1}` |
| | `factory creates a valid conduct` | Factory-built conduct is persisted |
| | `requires reason` | Conduct without reason fails validation |
| | `requires borrower` | Conduct without borrower fails validation |
| | `requires department` | Conduct without department fails validation |
| | `duration must be integer when present` | Float duration fails validation |
| | `duration allows nil` | Nil duration with `permanent: true` is valid |
| | `non-permanent conduct with no duration is invalid when user present` | Errors on `:permanent` when neither duration nor permanent is set |
| | `non-permanent conduct with positive duration is valid` | Duration-only conduct persists |
| | `permanent conduct without duration is valid` | Permanent conduct without duration persists |
| | `conduct without lending is valid` | Optional `lending` association allows nil |
| | `expired? returns true when duration has passed` | `:expired` factory trait produces `expired? == true` |
| | `expired? returns false when still valid` | 14-day duration is not expired |
| | `expired? returns false for permanent conduct` | Permanent conducts never expire |
| | `expired? returns false when no duration` | Automatic conduct (no duration) is not expired |
| | `days_remaining returns correct value` | 14-day conduct has ~14 days remaining |
| | `days_remaining returns nil for permanent` | Permanent conduct returns nil |
| | `days_remaining returns 0 when expired` | Expired conduct returns 0 |
| | `expiration_date returns correct date` | Returns `created_at + 14.days` |
| | `expiration_date returns nil for permanent` | Permanent conduct returns nil |
| | `automatic? returns true when user_id is nil` | Conduct without user is automatic |
| | `automatic? returns false when user is present` | Conduct with user is not automatic |
| | `remove_expired destroys expired conducts with duration` | Expired conduct is destroyed; valid conduct survives |
| | `remove_expired destroys stale automatic conducts` | Automatic conduct older than 60 days is destroyed |
| | `remove_expired does not destroy permanent conducts` | Permanent conduct is never removed |
| | `check_warning_escalation creates ban after 2 warnings` | Two warnings produce an automatic 30-day ban |
| | `check_warning_escalation does not create duplicate ban` | Existing ban prevents a second escalation |
| | `check_warning_escalation returns nil for fewer than 2 warnings` | Single warning returns nil |

## Manual verification

Run all conduct-related tests:

```bash
docker compose exec rails bundle exec rails test test/controllers/borrowers_controller_conduct_test.rb test/models/conduct_test.rb
```

Ban a borrower from the UI (`/verwaltung/:id`), then check Mailpit at http://localhost:8025 for the ban notification email.

Lift a ban via the "Sperre aufheben" modal and check Mailpit for the ban-lifted email.

Verify warning escalation from the console:

```bash
docker compose exec rails bundle exec rails console
# In the console:
borrower = Borrower.first
dept = Department.first
user = User.first
Conduct.create!(borrower: borrower, department: dept, user: user, kind: :warned, permanent: true, reason: "Test 1")
Conduct.create!(borrower: borrower, department: dept, user: user, kind: :warned, permanent: true, reason: "Test 2")
Conduct.where(borrower: borrower, kind: :banned).last
```
