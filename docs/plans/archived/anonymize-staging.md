# Anonymize Staging Data

## Goal

Create a rerunnable rake task (`rake staging:anonymize`) that replaces all PII
in borrowers and conducts with realistic Faker data so testers can be invited
to use the staging environment without seeing real personal information.

Users (staff accounts) are NOT anonymized -- they will be freshly invited.

## Branch

`feat-anonymize-staging` (based on `beta`)

## What to anonymize

### Borrowers

All non-deleted borrowers. For each:

| Field          | Replacement                                        |
| -------------- | -------------------------------------------------- |
| `firstname`    | `Faker::Name.first_name`                           |
| `lastname`     | `Faker::Name.last_name`                            |
| `email`        | `Faker::Internet.email` (unique)                   |
| `phone`        | `Faker::PhoneNumber.phone_number`                  |
| `student_id`   | Regenerate if present (e.g. numeric string)         |
| `email_token`  | `nil`                                              |

Already-anonymized borrowers (`@anonymized.local`) can be skipped.

### Conducts

| Field    | Replacement                                              |
| -------- | -------------------------------------------------------- |
| `reason` | Replace with generic text (e.g. `Faker::Lorem.sentence`) |

The `reason` field is freeform and may contain real names.

### Notes in lendings / item_histories

The `note` fields in `lendings` and `item_histories` could also contain names.
Scrub these too -- replace non-nil notes with `Faker::Lorem.sentence`.

### GDPR audit logs

Delete all `GdprAuditLog` records. They reference real anonymization/deletion
events from production and have no value on staging.

### After anonymization

- Call `Borrower.reindex` to update Searchkick/Elasticsearch indices.

## Implementation notes

- Faker is already in the Gemfile (test/development group): `faker 3.6.0`
- Use `update_columns` to skip validations and callbacks (like the existing
  `anonymize!` methods do).
- Wrap in a transaction for consistency.
- Add a `RAILS_ENV` / `BONANZA_ENV` guard so this can never run in production.
  Abort with a clear message if someone tries.
- The task must be **idempotent** -- safe to rerun after re-importing data.
- Seed Faker with a fixed seed per record (e.g. `Faker::Config.random = Random.new(record.id)`)
  so repeated runs produce the same fake data for the same records. This makes
  the output deterministic and debuggable.
- Skip borrowers that are already anonymized (`email.end_with?("@anonymized.local")`).

## TDD approach

1. Write a test for the rake task that:
   - Creates borrowers with real-looking data
   - Creates conducts with reasons containing names
   - Creates lendings/item_histories with notes
   - Runs the task
   - Asserts all PII fields are replaced
   - Asserts Borrower.reindex was called
   - Asserts the task is idempotent (run twice, still valid)
   - Asserts it refuses to run in production
2. Implement the rake task
3. Verify tests pass

## Files to create/modify

- `lib/tasks/staging.rake` -- the rake task
- `test/tasks/staging_rake_test.rb` (or spec equivalent) -- tests

## Out of scope

- User account anonymization (users will be freshly invited)
- Item/department/parent_item data (not PII)
- Changing passwords or Devise tokens on users
