# PR #125 Feedback Round 2

## Issues

### 1. Duplicate bans per department
- Multiple bans can be created for same borrower in same department
- Need: DB-level uniqueness constraint on active bans (borrower_id + department_id + kind=banned)
- Need: Model validation matching the constraint
- Need: UI hides "Sperren" button when already banned (partially done via has_bans_here?)

### 2. Second ban email not sent
- Likely consequence of issue #1 - if duplicate bans shouldn't exist, this resolves itself
- Still worth verifying the email path works for the single allowed ban

### 3. Ban lifted email still not working
- Fix was pushed (deliver_later before destroy) but still not working in Docker
- Possible causes: remove_conduct uses GET route (browser prefetch?), mailer template error, Solid Queue not processing default queue
- The GET route for a destructive action is suspicious - browsers/extensions can prefetch GET links

## Branch: feat/conduct-email-wiring
