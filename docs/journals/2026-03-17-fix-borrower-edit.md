# Fix: Employee Borrower Edit Error

Branch: `fix-borrower-edit`
PR: #249 (against beta)

## Problem

On staging, editing an employee borrower (`borrower_type: employee`) caused a
500 error (`ActiveRecord::RecordNotUnique`) when saving. The HANDOFF suspected
`id_checked` validation was the cause, but the actual root cause was different.

## Root Cause

The borrower edit form includes a hidden `student_id` text field for employees
(hidden via CSS `d-none`, but still in the DOM). When submitted, this field
sends an empty string `""` instead of null.

The database has a partial unique index:

```sql
CREATE UNIQUE INDEX index_borrowers_unique_student_id
  ON borrowers (student_id)
  WHERE student_id IS NOT NULL;
```

In PostgreSQL, `'' IS NOT NULL` is true. So once any employee had been edited
(getting `student_id = ""`), all subsequent employee edits tried to insert
another `""`, violating the unique constraint. The error was unhandled in the
controller, resulting in a 500.

The `id_checked` validation was a red herring -- it correctly only fires for
students (`if: Proc.new{|u| u.student? }`).

## Fix

Added `before_validation :normalize_student_id` callback in `Borrower` that
converts blank `student_id` to `nil`. This ensures employees consistently
store `NULL`, which the partial index correctly excludes.

## Files Changed

- `app/models/borrower.rb` -- added normalization callback
- `test/models/borrower_test.rb` -- 2 model tests for normalization
- `test/controllers/borrowers_controller_test.rb` -- 1 integration test

## Verification

- All 678 unit/integration tests pass
- E2E tested in browser:
  - Created two employee borrowers
  - Edited both sequentially (the exact failure scenario)
  - Both saved successfully; database confirmed `student_id = NULL`
  - Editing a student borrower also works (no regression)

## Key Insight

Empty string vs null mismatch is a common Rails/PostgreSQL gotcha. Rails
doesn't convert empty form strings to nil, and PostgreSQL treats `''` as
non-null. The partial unique index was designed correctly (`WHERE student_id
IS NOT NULL`) but the application layer wasn't normalizing inputs to match.

The existing test `"multiple employees with nil student_id do not conflict"`
used `save(validate: false)` with factory-default `nil` values, so it never
caught the empty-string path that real form submissions take.
