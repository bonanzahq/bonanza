# PR #126: GDPR Model Methods

Branch: `feat/gdpr-anonymize`
PR: https://github.com/bonanzahq/bonanza/pull/126
Status: Open

## Summary

Adds GDPR compliance methods to `Borrower` and `User`. `Borrower` gains `anonymize!`, `anonymized?`, `export_personal_data`, and `request_deletion!`. `User` gains `anonymize!` and `anonymized?`. A shared `GdprAuditable` concern logs GDPR actions as structured JSON to the Rails logger. Both models include the concern and call `log_gdpr_event` from within their `anonymize!` transactions.

## What changed

| File | Change |
|------|--------|
| `app/models/concerns/gdpr_auditable.rb` | New — `GdprAuditable` concern with private `log_gdpr_event(action, details = {})` that writes a structured JSON line to `Rails.logger.info` with `gdpr_audit: true`, action, model name, record ID, and timestamp |
| `app/models/borrower.rb` | Includes `GdprAuditable`; adds `anonymize!` (replaces PII fields, sets `borrower_type: :deleted`, calls `log_gdpr_event`), `anonymized?` (checks email suffix), `export_personal_data` (returns a hash with personal info, lendings, conducts, and `exported_at`), `request_deletion!` (blocks if active lendings exist; anonymizes if recent history, destroys otherwise) |
| `app/models/user.rb` | Includes `GdprAuditable`; adds `anonymize!` (sets all memberships to `deleted` role, replaces name/email/encrypted_password, calls `log_gdpr_event`), `anonymized?` (checks email suffix) |
| `test/models/borrower_gdpr_test.rb` | New — 12 tests for borrower GDPR methods |
| `test/models/user_gdpr_test.rb` | New — 4 tests for user GDPR methods |

## Why

GDPR requires the ability to export and erase personal data on request. This PR implements the data layer: anonymization zeroes out identifying fields in a transaction and logs an audit trail, export collects all personal data into a serialisable structure, and `request_deletion!` enforces the 7-year lending retention rule before deciding whether to anonymize or fully destroy the record.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/models/borrower_gdpr_test.rb` | `anonymize! replaces personal fields with placeholder values` | `firstname`, `lastname`, `email`, `phone`, `student_id`, `email_token` are overwritten; borrower type becomes `deleted` |
| | `anonymize! sets borrower_type to deleted` | `borrower_type` is `:deleted` after anonymization |
| | `anonymized? returns false before anonymization` | Fresh borrower is not marked anonymized |
| | `anonymized? returns true after anonymization` | Email ends with `@anonymized.local` after `anonymize!` |
| | `export_personal_data includes personal information` | Hash contains `id`, `firstname`, `lastname`, `email`, `phone`, `student_id`, `type` |
| | `export_personal_data includes lendings` | Hash contains one lending with `id`, `department`, and `items` array |
| | `export_personal_data includes conducts` | Hash contains one conduct with `type`, `reason`, `permanent`, `department` keys |
| | `export_personal_data includes exported_at timestamp` | `exported_at` key is present and non-blank |
| | `request_deletion! raises error when borrower has active lendings` | Raises `ActiveRecord::RecordNotDestroyed` when a lending has no `returned_at` |
| | `request_deletion! anonymizes borrower with recent lending history` | Returns `:anonymized` and `anonymized?` is true when a returned lending exists within 7 years |
| | `request_deletion! destroys borrower when no lendings exist` | Returns `:deleted` and borrower no longer exists in DB |
| | `request_deletion! destroys borrower when all lendings are older than 7 years` | Returns `:deleted` when all lendings are 8 years old |
| `test/models/user_gdpr_test.rb` | `anonymize! replaces personal fields with placeholder values` | `firstname`, `lastname`, `email`, `encrypted_password` are overwritten |
| | `anonymize! sets all department memberships to deleted role` | Every `DepartmentMembership` has role `"deleted"` after anonymization |
| | `anonymized? returns false before anonymization` | Fresh user is not marked anonymized |
| | `anonymized? returns true after anonymization` | Email ends with `@anonymized.local` after `anonymize!` |

## Manual verification

Run the GDPR model tests:

```bash
docker compose exec rails bundle exec rails test test/models/borrower_gdpr_test.rb test/models/user_gdpr_test.rb
```

Verify anonymization from the console:

```bash
docker compose exec rails bundle exec rails console
# In the console:
b = Borrower.first
b.anonymize!
b.reload
b.anonymized?        # => true
b.firstname          # => "Geloescht"
b.email              # => "deleted-<id>-<hex>@anonymized.local"
```

Export a borrower's data:

```bash
docker compose exec rails bundle exec rails console
# In the console:
b = Borrower.second
puts b.export_personal_data.to_json
```

Check that the GDPR audit log line appears in the Docker log output:

```bash
docker compose logs rails | grep gdpr_audit
```
