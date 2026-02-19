# PR #127: GDPR Scheduled Jobs

Branch: `feat/gdpr-rake-tasks`
PR: https://github.com/bonanzahq/bonanza/pull/127
Status: Open

## Summary

Adds three Solid Queue jobs that perform automated GDPR data minimisation on a weekly schedule: `GdprAnonymizeInactiveBorrowersJob` anonymizes borrowers with no lendings who have been untouched for 24+ months; `GdprAnonymizeOldBorrowersJob` anonymizes borrowers whose most recent lending is older than 7 years; `GdprCleanupOldConductsJob` bulk-destroys conduct records older than 5 years. All three are registered in `config/recurring.yml` (base is `feat/gdpr-anonymize`, so the file already contains the notification/cleanup recurring entries from PR #124; this PR adds GDPR entries on top).

## What changed

| File | Change |
|------|--------|
| `app/jobs/gdpr_anonymize_inactive_borrowers_job.rb` | New — queries borrowers with no lendings (`left_joins`) updated more than 24 months ago and not yet deleted; calls `borrower.anonymize!` on each; logs count; `low` queue |
| `app/jobs/gdpr_anonymize_old_borrowers_job.rb` | New — queries borrowers whose `MAX(lendings.created_at)` is older than 7 years and not yet deleted; calls `borrower.anonymize!` on each; logs count; `low` queue |
| `app/jobs/gdpr_cleanup_old_conducts_job.rb` | New — bulk-destroys conducts created more than 5 years ago via `destroy_all`; logs count; `low` queue |
| `config/recurring.yml` | Adds three GDPR entries for both `production` and `development`: `gdpr_anonymize_inactive_borrowers` (every Sunday 3:00 am), `gdpr_anonymize_old_borrowers` (every Sunday 3:15 am), `gdpr_cleanup_old_conducts` (every Sunday 3:30 am); also adds `clear_solid_queue_finished_jobs` command in production (every hour at minute 12) |
| `test/jobs/gdpr_anonymize_inactive_borrowers_job_test.rb` | New — verifies `low` queue and enqueuing |
| `test/jobs/gdpr_anonymize_old_borrowers_job_test.rb` | New — verifies `low` queue and enqueuing |
| `test/jobs/gdpr_cleanup_old_conducts_job_test.rb` | New — verifies `low` queue and enqueuing |

## Why

The GDPR model methods from PR #126 need a scheduler to run them regularly without manual intervention. Jobs are placed on the `low` queue so they do not compete with interactive notifications. Staggered Sunday early-morning slots (3:00, 3:15, 3:30 am) minimise database contention and spread the load. The 5-year conduct cleanup complements the 7-year lending retention rule already enforced by `request_deletion!`.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/jobs/gdpr_anonymize_inactive_borrowers_job_test.rb` | `job is queued to the low queue` | `perform_later` is enqueued on queue `"low"` via `assert_enqueued_with` |
| | `job can be enqueued` | `perform_later` enqueues `GdprAnonymizeInactiveBorrowersJob` |
| `test/jobs/gdpr_anonymize_old_borrowers_job_test.rb` | `job is queued to the low queue` | `perform_later` is enqueued on queue `"low"` |
| | `job can be enqueued` | `perform_later` enqueues `GdprAnonymizeOldBorrowersJob` |
| `test/jobs/gdpr_cleanup_old_conducts_job_test.rb` | `job is queued to the low queue` | `perform_later` is enqueued on queue `"low"` |
| | `job can be enqueued` | `perform_later` enqueues `GdprCleanupOldConductsJob` |

## Manual verification

Run all GDPR job tests:

```bash
docker compose exec rails bundle exec rails test test/jobs/gdpr_anonymize_inactive_borrowers_job_test.rb test/jobs/gdpr_anonymize_old_borrowers_job_test.rb test/jobs/gdpr_cleanup_old_conducts_job_test.rb
```

Confirm GDPR recurring tasks are registered after container startup:

```bash
docker compose exec rails bundle exec rails console
# In the console:
SolidQueue::RecurringTask.where("key LIKE 'gdpr%'").pluck(:key, :class_name, :schedule)
```

Run the inactive-borrowers job manually against a test record:

```bash
docker compose exec rails bundle exec rails console
# In the console:
b = Borrower.create!(firstname: "Test", lastname: "Inaktiv", email: "inaktiv@example.com", phone: "0", insurance_checked: true, borrower_type: :student, student_id: "S9999", id_checked: true, tos_accepted: true)
b.update_column(:updated_at, 25.months.ago)
GdprAnonymizeInactiveBorrowersJob.perform_now
b.reload.anonymized?   # => true
```

Check the Rails log for the GDPR audit entry:

```bash
docker compose logs rails | grep gdpr_audit
```
