# PR #121: UserMailer

Branch: `feat/user-mailer`
PR: https://github.com/bonanzahq/bonanza/pull/121
Merged: 2026-02-18

## Summary

Implements `UserMailer` with a `todays_returns_email` action that sends staff members a daily digest of lendings due back today, including a count of unreturned line items across those lendings.

## What changed

| File | Change |
|------|--------|
| `app/mailers/user_mailer.rb` | New mailer class with `todays_returns_email(user, department, lendings)` — computes total unreturned line items and mails a digest to the user |
| `app/views/user_mailer/todays_returns_email.html.erb` | HTML template for the daily returns digest |
| `app/views/user_mailer/todays_returns_email.text.erb` | Plain-text template for the daily returns digest |
| `test/mailers/user_mailer_test.rb` | New test file — 4 tests covering recipient, subject, enqueue behaviour, and body content |

## Why

Staff members need a daily summary of equipment due back so they can follow up with borrowers proactively. The email is scoped per user and per department, and includes the borrower name for each lending so staff can identify who owes what at a glance.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/mailers/user_mailer_test.rb` | `todays_returns_email is addressed to the user` | `to:` is the staff user's email |
| | `todays_returns_email has correct subject` | Subject contains `Heutige Rueckgaben` and the department name |
| | `todays_returns_email is enqueued with deliver_later` | Email is enqueued via ActiveJob |
| | `todays_returns_email body contains borrower name` | Email body includes the borrower's full name |

## Manual verification

Run the mailer tests:

```bash
docker compose exec rails bundle exec rails test test/mailers/user_mailer_test.rb
```

Send a test digest from the Rails console:

```bash
docker compose exec rails bundle exec rails console
# In the console:
user = User.first
department = user.department
lendings = Lending.where(department: department).completed.where(lent_at: ..Date.today)
UserMailer.todays_returns_email(user, department, lendings).deliver_later
```

Check Mailpit at http://localhost:8025 to verify the email arrives addressed to the user, with a subject containing `Heutige Rueckgaben` and the department name, and that the body lists borrower names.
