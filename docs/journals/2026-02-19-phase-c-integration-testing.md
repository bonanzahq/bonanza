# Phase C Integration Testing

## Summary

Integration tested all Phase C PRs (#123-#128) in a Docker environment. All checklist items pass after fixes.

## What was tested

1. Solid Queue worker - supervisor, 3 queue workers (critical/default/low), 9 recurring tasks
2. Lending confirmation email - works
3. Duration change email - works
4. Ban notification email - works (timed + permanent)
5. Conduct expiration display - works
6. Ban lifted email - works after fix
7. GDPR data export - JSON with personal_information, lendings, conducts, exported_at
8. GDPR deletion - anonymizes without active lendings, blocks with active lendings

## Bugs found and fixed

### Ban lifted email not sent (PR #125)

Root cause: `deliver_later` serializes ActiveRecord objects via GlobalID. The conduct was destroyed after enqueuing, so when the worker processed the job, `Conduct.find(id)` failed silently. Moving `deliver_later` before `destroy` didn't help because `deliver_later` is async - the worker still runs after destroy completes.

Fix: Changed `ban_lifted_notification_email` to accept keyword primitives (department_name, user_fullname, etc.) instead of ActiveRecord objects. Data extracted in controller before destroy.

### Duplicate bans per department (PR #125)

Users could create multiple bans for the same borrower in the same department. Added model validation and partial unique DB index on `(borrower_id, department_id) WHERE kind = 1`.

### remove_conduct uses GET for destructive action (PR #125)

Changed route from GET to DELETE. Updated view link to `button_to` with `method: :delete`.

### GDPR deletion flash not visible (PR #128)

The `button_to` in the delete modal used Turbo by default. Combined with `data-turbo-permanent` on the flash container, the error flash wasn't rendered. Fixed by adding `data: { turbo: false }`.

### Missing umlauts (PR #128)

Flash messages used ASCII-safe German ("Loeschung", "geloescht"). Fixed to proper umlauts.

## UI fixes

- Daten section moved to left side, above Bearbeiten button
- Sperren button icon removed for consistent button height
- Datepicker placeholder "Datum wahlen" added
- All buttons normalized to btn-sm
- Conduct form reason field marked required

## Issues filed for later

- `b1765d9` - Borrower selection view shows no initial list (bug, phase-c)
- `42cacfc` - Retain conduct records when bans are lifted (enhancement, phase-c)
- `da8262d` - Replace toasts with persistent error messages (enhancement, phase-d)
- `c293b30` - Staff-created borrowers receive no notification email (bug, phase-c)

## Approach notes

- Used subagent workers for parallel fixes across branches (feat/conduct-email-wiring, feat/gdpr-data-export)
- Had to correct subagent mistakes: one added GDPR buttons to a branch that didn't have the routes, another disabled the export button despite the action existing
- Test DB in Docker needs `DATABASE_URL` env var for `db:test:prepare` since dev DB config uses socket not TCP

## PR

All merged into test-phase-c, PR #129 to main.
