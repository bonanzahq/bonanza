# fix/staff-borrower-email

## Problem

When staff creates a borrower via /verwaltung/new, no notification email was
sent. The borrower's personal data was stored without their knowledge.
Self-registered borrowers already received a confirmation email via
`send_confirmation_pending_email`, but staff-created borrowers bypassed this.

## Solution

Added `account_created_email` to `BorrowerMailer`, wired into
`BorrowersController#create` with `deliver_later`. The email informs the
borrower that their account was created, by which department, that their data
is stored, and how to request changes/deletion.

## Changes

- `app/mailers/borrower_mailer.rb` -- new `account_created_email(department_name:)` method
- `app/views/borrower_mailer/account_created_email.{html,text}.erb` -- templates matching existing email style
- `app/controllers/borrowers_controller.rb` -- `deliver_later` call after successful save in `create`
- `test/mailers/borrower_mailer_test.rb` -- 6 tests (enqueue, addressing, subject, multipart, department/name in body)
- `test/controllers/borrowers_controller_test.rb` -- 2 tests (email enqueued on create, no email on validation failure)

## E2E verification

Full Docker stack tested with browser automation:
- Logged in as admin, created a borrower via the form
- Verified email arrived in Mailpit with correct subject, recipient, and content
- HTML template renders correctly (matching existing email design)

## Bugs discovered during testing

- **git-bug 3a92054**: Hyperform client-side validation blocks borrower form
  when switching from student to employee. The student_id field retains a
  custom validity error even when hidden. Confirmed by Fabian manually.
- **git-bug 099211e**: Insurance check required for employee borrowers, but
  employees are insured through the university.
- **git-bug 70979dd**: Missing database unique index on borrower student_id.
  Model validates uniqueness but no DB constraint backs it.
