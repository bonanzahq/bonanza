# PR #125 Feedback Plan

## Issues from integration testing

### Bug 1: Ban notification email not sent on first ban (critical)

**Symptom**: First ban creates no email. Second ban does. Timespan bans don't
send email, only permanent bans.

**Root cause hypothesis**: The `remove_conduct` action uses a GET request
(`get 'ausleiher/:id/verhalten/:conducts_id/entfernen'`). The `add_conduct`
sends emails in the controller after `@conduct.save`, and the model's
`after_create_commit :notify_and_escalate` ALSO sends emails for automatic
bans. But the controller email (`BorrowerMailer...ban_notification_email`)
should fire for every manual ban. Need to investigate whether Solid Queue
is processing jobs correctly on first save.

Actually, looking more carefully: the `after_create_commit :notify_and_escalate`
callback only fires `auto_ban_notification_email` for `banned? && automatic?`
conducts, and `check_warning_escalation` for warnings. So for manual bans,
only the controller's `deliver_later` should fire. If the worker isn't ready
or there's a queue issue on the first request, that could explain it.

Need to check:
- Is the Solid Queue worker processing the `critical` queue?
- Is there a race condition where the worker isn't fully started?
- Is `deliver_later` actually enqueuing the job?
- Check Solid Queue's `solid_queue_jobs` table after a ban

### Bug 2: Ban lifted email not sent (critical)

**Symptom**: Removing a ban doesn't send the "Sperre aufgehoben" email.

**Root cause hypothesis**: In `remove_conduct`, the conduct is destroyed
BEFORE `deliver_later` is called. When the mailer job executes later, it
tries to access `@conduct.department` and `@conduct.user` but the record
is already destroyed. The `ban_lifted_notification_email` takes `conduct`
and `user` as arguments (not ActiveRecord params), but `conduct` is a
destroyed record. The template accesses `@conduct.department` which may
fail because the association can't be loaded after destroy.

Actually: `deliver_later` serializes the arguments. `conduct` is an
ActiveRecord object that's been destroyed - ActiveJob will try to serialize
it via GlobalID, which will fail because the record no longer exists. This
is almost certainly the root cause.

**Fix**: Pass the needed data (department name, etc.) as plain values instead
of the destroyed record, OR send the email synchronously before destroying,
OR move to `deliver_later` with extracted data.

### UI Issue 1: Button layout on borrower detail page

**Symptom**: Buttons at bottom have different heights, text not centered.
"Daten loeschen" should be "Daten loschen" (with umlaut). Ban button shown
even when already banned.

**Fix**:
- Normalize button sizes (use same `btn-sm` or remove it consistently)
- Fix umlaut: "Daten loschen" -> "Daten loschen" (actually the current text
  says "Daten loeschen" which is the ASCII-safe version - Fabian wants proper
  umlaut "Daten loschen")
- Hide "Sperren" button when borrower already has ban in current department

### UI Issue 2: Reorganize borrower detail sections

**Fabian's suggestion**:
```
Data
  - Export
  - Erase (with modal explaining anonymization, not just alert)
Ban
  - Ban/Unban
  - Alter ban
  (Remove conduct info from top of page)
Edit button
```

### UI Issue 3: Frontend validation for conduct form

**Symptom**: No `required` attributes on form fields.

**Fix**: Add `required: true` to reason field and ensure duration or permanent
checkbox is required.

## Execution order

1. Fix Bug 2 first (ban lifted email) - most likely a serialization issue
2. Fix Bug 1 (ban notification not sent on first ban) - needs investigation
3. UI fixes (button layout, section reorganization, validation)
