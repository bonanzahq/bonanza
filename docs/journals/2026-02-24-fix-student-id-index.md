# fix/student-id-index session

## What we did

Added a conditional unique database index on `borrowers.student_id` to enforce
uniqueness at the DB level. The model-level `validates :student_id, uniqueness: true`
already existed but couldn't prevent race condition duplicates.

### Migration

- Created `db/migrate/20260223141942_add_unique_index_to_borrowers_student_id.rb`
- Partial unique index: `WHERE student_id IS NOT NULL`
- Allows multiple NULL values (employees don't have student IDs)

### Tests (TDD)

Added two tests to `test/models/borrower_test.rb`:
- `duplicate student_id raises at database level` - verifies DB constraint via `save(validate: false)`
- `multiple employees with nil student_id do not conflict` - verifies NULL handling

### E2E verification

Spun up the full Docker stack and verified:
1. UI rejects duplicate student_id (model validation: "Matrikelnummer ist bereits vergeben")
2. Rails console `save(validate: false)` raises `PG::UniqueViolation`
3. Multiple employees with NULL student_id coexist without conflict
4. Index confirmed in PostgreSQL: `index_borrowers_unique_student_id`

### Data migration note

Added a note to `docs/plans/d1_data-migration.md` about handling potential
duplicate student_ids in v1 data during the future data migration. The index
will be in place before data import, so duplicates will be caught at import time.

### Cleanup

- Removed orphaned Docker volumes from 5 old worktrees (fix-borrower-ui,
  fix-borrower-selection, fix-staff-borrower-email, feat-gdpr-audit, test-phase-c)
- Stopped the old fix-borrower-ui Docker stack that was still running

### Copilot PR review

Copilot suggested two changes on PR #153:
1. Pre-migration duplicate check - dismissed (Postgres already gives a clear error)
2. Concurrent index creation - dismissed (tiny table, not worth the complexity)

## Issue

git-bug 70979dd - closed

## PR

https://github.com/bonanzahq/bonanza/pull/153
