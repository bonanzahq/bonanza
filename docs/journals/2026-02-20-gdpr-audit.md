# GDPR Audit Logging

## Summary

Implemented persistent database-backed GDPR audit logging, replacing the
ephemeral Rails.logger-only approach. Manually tested all three GDPR paths
(export, deletion-via-anonymize, deletion-via-destroy) in Docker.

## What was built

1. **Migration**: `gdpr_audit_logs` table with polymorphic `target` and
   `performed_by`, JSONB `metadata`, indexed on `(target_type, target_id)`
   and `action`.

2. **Model**: `GdprAuditLog` with validations (action inclusion in defined
   set), scopes (`for_action`, `for_target`), and polymorphic associations.

3. **Updated `GdprAuditable` concern**: `log_gdpr_event` now creates a DB
   record AND keeps the Rails.logger line. Added `performed_by:` and
   `metadata:` keyword params. Made the method public (needed by controller).
   Added `gdpr_audit_logs` association without `dependent: :destroy` -- audit
   logs must survive target deletion.

4. **Wired up all GDPR actions**:
   - `Borrower#anonymize!` and `User#anonymize!` accept `performed_by:`
   - `Borrower#request_deletion!` logs `deletion_requested` before action
   - `BorrowersController#export_data` logs `export` with `current_user`
   - `BorrowersController#request_deletion` passes `current_user` through
   - Background jobs create audit logs with `performed_by: nil`

5. **Changed `export_data` route from GET to POST**: during manual testing,
   the browser sent the GET request twice (common with file downloads),
   creating duplicate audit entries. POST prevents this. Added
   `data: { turbo: false }` to the button so the file download works
   through Turbo.

## Design decisions

- **No `dependent: :destroy`** on `gdpr_audit_logs` association. Audit logs
  must persist even when the target is destroyed (e.g., full deletion via
  `request_deletion!`). Orphaned `target_id` references are acceptable for
  audit records.

- **`log_gdpr_event` is public**, not private. The controller needs to call
  it for the export action.

- **Audit metadata is intentionally empty** for all current actions. Storing
  personal data in the audit log would defeat the purpose of anonymization.
  The log proves an action happened (who, what, when), not what data existed.

- **No `AnonymizeOffboardedUsersJob`** exists despite the HANDOFF mentioning
  it. The actual jobs are `GdprAnonymizeInactiveBorrowersJob` and
  `GdprAnonymizeOldBorrowersJob`. Filed a separate issue for staff user
  cleanup.

## Issues filed

Three follow-up issues filed with the `gdpr` label (all phase-c):

- **ce2d2d5**: Self-service GDPR data export and deletion request for
  borrowers via magic link authentication
- **cb2a00f**: Automatic anonymization of inactive staff users (no cleanup
  exists today)
- **f0478dd**: Early data minimization for inactive borrowers within the
  7-year retention period (strip phone/student ID after 24 months)

## Test database note

The test DB container (`bonanza-test-db`) is on port 5433, not 5432. Must
set `TEST_DATABASE_PORT=5433` when running tests.

## Pre-existing test failures

Two controller index tests and a mailer test fail due to a stale
Elasticsearch index in the test environment. Not related to this branch.
