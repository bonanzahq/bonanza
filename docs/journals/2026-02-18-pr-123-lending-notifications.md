# PR #123: Lending Notifications

Branch: `feat/lending-notifications`
PR: https://github.com/bonanzahq/bonanza/pull/123
Status: Open

## Summary

Extracts the four lending notification class methods (`notify_borrowers_of_overdue_lending`, `notify_borrowers_of_upcoming_return`, `notify_borrowers_of_staffed_department`) and the `finalize!` confirmation email into well-tested, cohesive model logic. The `LendingController#change_duration` action is wired up to send a `duration_change_notification_email` via `deliver_later`. A dedicated test file verifies all notification paths including staffed-department guard conditions and the confirmation email sent on checkout completion.

## What changed

| File | Change |
|------|--------|
| `app/models/lending.rb` | Refactored notification methods: SQL conditions now use PostgreSQL interval arithmetic; `finalize!` sends `confirmation_email` on `:critical` queue via `deliver_later`; `notify_borrowers_of_overdue_lending`, `notify_borrowers_of_upcoming_return`, and `notify_borrowers_of_staffed_department` guard against unstaffed departments |
| `app/controllers/lending_controller.rb` | `change_duration` action sends `LendingMailer.duration_change_notification_email` via `deliver_later(queue: :default)` after a successful duration update |
| `test/models/lending_notification_test.rb` | New file — 12 tests covering all four notification class methods and the `finalize!` confirmation email |

## Why

Lending notifications were implemented as model class methods but had no test coverage and no guarantee that the mailer calls were actually queued. This PR adds comprehensive tests using `assert_enqueued_emails` and ensures all notification code paths respect the `department.staffed` guard, preventing emails from being sent for closed workshops.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/models/lending_notification_test.rb` | `notify_borrowers_of_overdue_lending enqueues email for overdue lending in staffed department` | One email is enqueued when a lending is past its due date and the department is staffed |
| | `notify_borrowers_of_overdue_lending skips lending in unstaffed department` | No email is enqueued when the department has `staffed: false` |
| | `notify_borrowers_of_overdue_lending skips already returned lending` | No email is enqueued when `returned_at` is set |
| | `notify_borrowers_of_overdue_lending skips lending not yet due` | No email is enqueued when the lending is within its duration |
| | `notify_borrowers_of_upcoming_return enqueues email for lending due tomorrow` | One email is enqueued when `lent_at + duration = tomorrow` |
| | `notify_borrowers_of_upcoming_return skips lending due today` | No email is enqueued when due date is today (already passed) |
| | `notify_borrowers_of_upcoming_return skips lending in unstaffed department` | No email for unstaffed department even when due tomorrow |
| | `notify_borrowers_of_staffed_department enqueues email for overdue lending when department reopened today` | One email when `staffed_at.to_date == Date.current` and lending is overdue |
| | `notify_borrowers_of_staffed_department skips lending when department reopened yesterday` | No email when `staffed_at` is in the past |
| | `notify_borrowers_of_staffed_department skips non-overdue lending` | No email when lending is not yet past due |
| | `finalize! enqueues confirmation email` | `update_from_checkout_params` enqueues exactly one email when transitioning a confirmation-state lending to completed |

## Manual verification

Run the notification tests:

```bash
docker compose exec rails bundle exec rails test test/models/lending_notification_test.rb
```

Trigger `notify_borrowers_of_overdue_lending` from the console and inspect the queue:

```bash
docker compose exec rails bundle exec rails console
# In the console:
Lending.notify_borrowers_of_overdue_lending
SolidQueue::Job.where(class_name: "ActionMailer::MailDeliveryJob").last(5)
```

Change a lending duration via the UI (`/ausleihe/:id/token/:token`) and check Mailpit at http://localhost:8025 for the duration-change notification email.
