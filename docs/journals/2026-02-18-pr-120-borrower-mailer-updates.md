# PR #120: BorrowerMailer Updates

Branch: `feat/borrower-mailer-updates`
PR: https://github.com/bonanzahq/bonanza/pull/120
Merged: 2026-02-18

## Summary

Extends `BorrowerMailer` with three conduct-related email actions: ban notification (staff-issued), ban lifted notification, and automatic ban notification (system-issued after warning escalation). Adds comprehensive tests for all four mailer actions including the pre-existing `confirm_email`.

## What changed

| File | Change |
|------|--------|
| `app/mailers/borrower_mailer.rb` | Added `ban_notification_email(conduct)`, `ban_lifted_notification_email(conduct, user)`, and `auto_ban_notification_email(conduct)` actions to the existing mailer |
| `app/views/borrower_mailer/ban_notification_email.html.erb` | HTML template for staff-issued ban notification |
| `app/views/borrower_mailer/ban_notification_email.text.erb` | Plain-text template for staff-issued ban notification |
| `app/views/borrower_mailer/ban_lifted_notification_email.html.erb` | HTML template for ban lifted notification |
| `app/views/borrower_mailer/ban_lifted_notification_email.text.erb` | Plain-text template for ban lifted notification |
| `app/views/borrower_mailer/auto_ban_notification_email.html.erb` | HTML template for automatic ban notification |
| `app/views/borrower_mailer/auto_ban_notification_email.text.erb` | Plain-text template for automatic ban notification |
| `test/mailers/borrower_mailer_test.rb` | Extended with 12 new tests covering all three new actions plus HTML/text multipart assertions |

## Why

When a borrower is banned or warned, they need to be notified by email so they understand the situation and can contact the responsible staff member. When a ban is lifted, a notification ensures borrowers know they can borrow again. Automatic bans (triggered by the warning escalation logic in PR #122) have no associated staff member, so the `auto_ban_notification_email` omits `reply_to` and uses the department name in the subject. Having both HTML and text parts ensures deliverability across different email clients.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/mailers/borrower_mailer_test.rb` | `confirm_email is enqueued with deliver_later` | Registration confirmation enqueues via ActiveJob |
| | `confirm_email is addressed to the borrower` | `to:` is the borrower's email |
| | `confirm_email has both HTML and text parts` | Multipart email with `html_part` and `text_part` |
| | `ban_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `ban_notification_email has correct subject` | Subject is `Du wurdest gesperrt.` |
| | `ban_notification_email has correct reply_to` | `reply_to` is the issuing staff member's email |
| | `ban_notification_email has both HTML and text parts` | Multipart email with `html_part` and `text_part` |
| | `ban_lifted_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `ban_lifted_notification_email has correct subject` | Subject is `Deine Sperre wurde aufgehoben!` |
| | `ban_lifted_notification_email has correct reply_to` | `reply_to` is the lifting user's email |
| | `ban_lifted_notification_email has both HTML and text parts` | Multipart email with `html_part` and `text_part` |
| | `auto_ban_notification_email is addressed to the borrower` | `to:` is the borrower's email |
| | `auto_ban_notification_email subject contains department name` | Subject includes the department name |
| | `auto_ban_notification_email subject starts with Automatische Sperre` | Subject prefix is `Automatische Sperre` |
| | `auto_ban_notification_email has both HTML and text parts` | Multipart email with `html_part` and `text_part` |

## Manual verification

Run the mailer tests:

```bash
docker compose exec rails bundle exec rails test test/mailers/borrower_mailer_test.rb
```

Trigger a ban notification from the Rails console:

```bash
docker compose exec rails bundle exec rails console
# In the console:
conduct = Conduct.banned.first
BorrowerMailer.with(borrower: conduct.borrower).ban_notification_email(conduct).deliver_later
```

Check Mailpit at http://localhost:8025 to verify the email arrives with subject `Du wurdest gesperrt.` and that the reply-to header points to the staff member's email address.
