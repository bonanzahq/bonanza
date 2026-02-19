# PR #119: LendingMailer

Branch: `feat/lending-mailer`
PR: https://github.com/bonanzahq/bonanza/pull/119
Merged: 2026-02-18

## Summary

Implements `LendingMailer` with six actions covering the full lending lifecycle: borrowing confirmation, overdue reminders, upcoming return reminders, last-day return warnings, duration change notifications, and department re-opening notifications. Each action ships both HTML and plain-text templates.

## What changed

| File | Change |
|------|--------|
| `app/mailers/lending_mailer.rb` | New mailer class with six actions: `confirmation_email`, `overdue_notification_email`, `upcoming_return_notification_email`, `upcoming_overdue_return_notification_email`, `duration_change_notification_email`, `department_staffed_again_notification_email` |
| `app/views/lending_mailer/confirmation_email.html.erb` | HTML template for lending confirmation |
| `app/views/lending_mailer/confirmation_email.text.erb` | Plain-text template for lending confirmation |
| `app/views/lending_mailer/overdue_notification_email.html.erb` | HTML template for overdue notice |
| `app/views/lending_mailer/overdue_notification_email.text.erb` | Plain-text template for overdue notice |
| `app/views/lending_mailer/upcoming_return_notification_email.html.erb` | HTML template for upcoming return reminder |
| `app/views/lending_mailer/upcoming_return_notification_email.text.erb` | Plain-text template for upcoming return reminder |
| `app/views/lending_mailer/upcoming_overdue_return_notification_email.html.erb` | HTML template for last-day return warning |
| `app/views/lending_mailer/upcoming_overdue_return_notification_email.text.erb` | Plain-text template for last-day return warning |
| `app/views/lending_mailer/duration_change_notification_email.html.erb` | HTML template for duration change notice |
| `app/views/lending_mailer/duration_change_notification_email.text.erb` | Plain-text template for duration change notice |
| `app/views/lending_mailer/department_staffed_again_notification_email.html.erb` | HTML template for department re-opening notice |
| `app/views/lending_mailer/department_staffed_again_notification_email.text.erb` | Plain-text template for department re-opening notice |
| `test/mailers/lending_mailer_test.rb` | New test file — 18 tests covering all six actions |

## Why

Borrowers need transactional email at key moments of the lending lifecycle: when equipment is handed over, when it is overdue, when return is approaching, and when a department re-opens. Previously these emails were unimplemented stubs. All emails set `reply_to` to the responsible staff member so borrowers can respond directly to the right person.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/mailers/lending_mailer_test.rb` | `confirmation_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `confirmation_email is addressed to the borrower` | `to:` is the borrower's email |
| | `confirmation_email has correct subject` | Subject is `Ausleihbestaetigung` |
| | `confirmation_email has reply_to set to lending user` | `reply_to` contains the lending user's email |
| | `overdue_notification_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `overdue_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `overdue_notification_email has correct subject` | Subject is `Erinnerung: Leihfrist ueberschritten` |
| | `overdue_notification_email has reply_to set to lending user` | `reply_to` contains the lending user's email |
| | `upcoming_return_notification_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `upcoming_return_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `upcoming_return_notification_email has correct subject` | Subject is `Erinnerung: Anstehende Rueckgabe` |
| | `upcoming_return_notification_email has reply_to set to lending user` | `reply_to` contains the lending user's email |
| | `upcoming_overdue_return_notification_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `upcoming_overdue_return_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `upcoming_overdue_return_notification_email has correct subject` | Subject is `Letzte Erinnerung: Rueckgabe morgen` |
| | `upcoming_overdue_return_notification_email has reply_to set to lending user` | `reply_to` contains the lending user's email |
| | `duration_change_notification_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `duration_change_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `duration_change_notification_email has correct subject` | Subject is `Aenderung Deiner Ausleihfrist` |
| | `duration_change_notification_email has reply_to set to lending user` | `reply_to` contains the lending user's email |
| | `department_staffed_again_notification_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `department_staffed_again_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `department_staffed_again_notification_email has correct subject` | Subject contains the department name and `ist wieder geoeffnet` |

## Manual verification

Run the full mailer test suite:

```bash
docker compose exec rails bundle exec rails test test/mailers/lending_mailer_test.rb
```

Send a test email from the Rails console and inspect it in Mailpit:

```bash
docker compose exec rails bundle exec rails console
# In the console:
lending = Lending.completed.first
LendingMailer.confirmation_email(lending).deliver_later
```

Check Mailpit at http://localhost:8025 to verify the email arrives with the correct subject, recipient, and reply-to header.
