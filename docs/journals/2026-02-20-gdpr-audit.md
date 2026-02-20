# GDPR Audit Logging

## Summary

Implemented persistent database-backed GDPR audit logging, replacing the
ephemeral Rails.logger-only approach.

## What was built

1. **Migration**: `gdpr_audit_logs` table with polymorphic `target` and
   `performed_by`, JSONB `metadata`, indexed on `(target_type, target_id)`
   and `action`.

2. **Model**: `GdprAuditLog` with validations (action inclusion in defined set),
   scopes (`for_action`, `for_target`), and polymorphic associations.

3. **Updated `GdprAuditable` concern**: `log_gdpr_event` now creates a DB
   record AND keeps the Rails.logger line. Added `performed_by:` and
   `metadata:` keyword params. Made the method public (needed by controller).
   Added `gdpr_audit_logs` association (no `dependent: :destroy` -- audit logs
   must survive target deletion).

4. **Wired up all GDPR actions**:
   - `Borrower#anonymize!` and `User#anonymize!` accept `performed_by:`
   - `Borrower#request_deletion!` logs `deletion_requested` before action
   - `BorrowersController#export_data` logs `export` with `current_user`
   - `BorrowersController#request_deletion` passes `current_user` through
   - Background jobs create audit logs with `performed_by: nil`

## Design decisions

- No `dependent: :destroy` on `gdpr_audit_logs` association. Audit logs must
  persist even when the target is destroyed (e.g., full deletion via
  `request_deletion!`). Orphaned `target_id` references are acceptable for
  audit records.
- `log_gdpr_event` is public, not private. The controller needs to call it
  for the export action.
- The HANDOFF mentioned `AnonymizeOffboardedUsersJob` but it doesn't exist.
  The actual jobs are `GdprAnonymizeInactiveBorrowersJob` and
  `GdprAnonymizeOldBorrowersJob`.

## Test database note

The test DB container (`bonanza-test-db`) is on port 5433, not 5432. Must
set `TEST_DATABASE_PORT=5433` when running tests.
