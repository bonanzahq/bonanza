# fix/retain-conducts

## Summary

Implemented soft-delete for conducts. When a ban is lifted, the conduct record
is preserved with `lifted_at` and `lifted_by_id` instead of being destroyed.

## Changes

- Migration: added `lifted_at` (datetime) and `lifted_by_id` (FK to users) to
  conducts table. Updated partial unique index to exclude lifted bans.
- Conduct model: added `lift!(user)`, `lifted?`, `active`/`lifted` scopes.
  Updated uniqueness validation, `remove_expired`, and `check_warning_escalation`
  to only consider active (non-lifted) conducts.
- Borrower model: `has_bans_in?`, `has_warnings_in?`, `has_misconduct_in?` now
  use `conducts.active` scope. `search_data` reflects active conducts only.
  GDPR export includes `lifted_at` and `lifted_by` for lifted conducts.
- Controller: `remove_conduct` calls `@conduct.lift!(current_user)` instead of
  `@conduct.destroy`.
- View: restructured conduct display into vertical flow layout. Each conduct
  shows department/duration, reason, and lift button as separate paragraphs.
  Lifted conducts appear in a collapsible `<details>` section with the same
  structure, greyed out.

## Layout revision

After Fabian's review, restructured the conduct display from inline `<li>`
elements to a vertical block layout with:
1. Department + time/duration info as first paragraph
2. Reason with "Grund:" label as second paragraph
3. Lift button as third paragraph

Applied same structure to lifted conducts in the collapsible section.

## Open question

Where should lifted conducts live: in the "Sperre" section (current) or in
"Verlauf" (chronological history)? Filed as git-bug 5426799.

## Testing

- 449 tests, 0 failures, 0 errors
- E2E browser test verified: ban displayed, lift modal works, lifted conduct
  appears in collapsible section with correct metadata
- Manual review by Fabian confirmed layout improvements
