# PR #124: Scheduled Jobs

Branch: `feat/scheduled-jobs`
PR: https://github.com/bonanzahq/bonanza/pull/124
Status: Open

## Summary

Introduces six `ApplicationJob` subclasses that delegate to existing model methods and mailer calls, and registers them as Solid Queue recurring tasks in `config/recurring.yml`. Jobs cover overdue notifications, upcoming return reminders, staffed-department re-open notifications, daily staff digest emails, expired conduct cleanup (with ban-lifted emails), and abandoned cart removal. Each job has a corresponding test verifying its queue assignment and that it can be enqueued.

## What changed

| File | Change |
|------|--------|
| `app/jobs/send_overdue_notifications_job.rb` | New — calls `Lending.notify_borrowers_of_overdue_lending`; `default` queue; scheduled daily at 7:30 pm Europe/Berlin |
| `app/jobs/send_upcoming_return_reminders_job.rb` | New — calls `Lending.notify_borrowers_of_upcoming_return`; `default` queue; scheduled daily at 6:00 pm Europe/Berlin |
| `app/jobs/send_staffed_department_notifications_job.rb` | New — calls `Lending.notify_borrowers_of_staffed_department`; `default` queue; scheduled daily at 6:45 pm Europe/Berlin |
| `app/jobs/send_staff_daily_returns_job.rb` | New — iterates all departments, finds lendings due today, emails non-guest staff via `UserMailer.todays_returns_email`; `low` queue; scheduled daily at 7:30 am Europe/Berlin |
| `app/jobs/cleanup_expired_conducts_job.rb` | New — calls `Conduct.remove_expired`, sends `ban_lifted_notification_email` for each removed conduct; `low` queue; scheduled daily at 8:00 pm Europe/Berlin |
| `app/jobs/cleanup_abandoned_carts_job.rb` | New — calls `Lending.remove_abandoned_carts`; `low` queue; scheduled daily at 11:30 pm Europe/Berlin |
| `config/recurring.yml` | Registers all six jobs for both `production` and `development` environments |
| `test/jobs/send_overdue_notifications_job_test.rb` | New — verifies `default` queue and enqueuing |
| `test/jobs/send_upcoming_return_reminders_job_test.rb` | New — verifies `default` queue and enqueuing |
| `test/jobs/send_staffed_department_notifications_job_test.rb` | New — verifies `default` queue and enqueuing |
| `test/jobs/send_staff_daily_returns_job_test.rb` | New — verifies `low` queue and enqueuing |
| `test/jobs/cleanup_expired_conducts_job_test.rb` | New — verifies `low` queue and enqueuing |
| `test/jobs/cleanup_abandoned_carts_job_test.rb` | New — verifies `low` queue and enqueuing |

## Why

The application's notification and cleanup logic existed as model class methods with no scheduled runner. This PR hooks those methods into Solid Queue's recurring task system so they execute automatically each day in production without manual intervention or an external cron daemon.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/jobs/send_overdue_notifications_job_test.rb` | `uses default queue` | `SendOverdueNotificationsJob.new.queue_name` equals `"default"` |
| | `can be enqueued` | `perform_later` enqueues the job with `assert_enqueued_with` |
| `test/jobs/send_upcoming_return_reminders_job_test.rb` | `uses default queue` | `SendUpcomingReturnRemindersJob.new.queue_name` equals `"default"` |
| | `can be enqueued` | `perform_later` enqueues the job |
| `test/jobs/send_staffed_department_notifications_job_test.rb` | `uses default queue` | `SendStaffedDepartmentNotificationsJob.new.queue_name` equals `"default"` |
| | `can be enqueued` | `perform_later` enqueues the job |
| `test/jobs/send_staff_daily_returns_job_test.rb` | `uses low queue` | `SendStaffDailyReturnsJob.new.queue_name` equals `"low"` |
| | `can be enqueued` | `perform_later` enqueues the job |
| `test/jobs/cleanup_expired_conducts_job_test.rb` | `uses low queue` | `CleanupExpiredConductsJob.new.queue_name` equals `"low"` |
| | `can be enqueued` | `perform_later` enqueues the job |
| `test/jobs/cleanup_abandoned_carts_job_test.rb` | `uses low queue` | `CleanupAbandonedCartsJob.new.queue_name` equals `"low"` |
| | `can be enqueued` | `perform_later` enqueues the job |

## Manual verification

Run all job tests:

```bash
docker compose exec rails bundle exec rails test test/jobs/cleanup_abandoned_carts_job_test.rb test/jobs/cleanup_expired_conducts_job_test.rb test/jobs/send_overdue_notifications_job_test.rb test/jobs/send_staff_daily_returns_job_test.rb test/jobs/send_staffed_department_notifications_job_test.rb test/jobs/send_upcoming_return_reminders_job_test.rb
```

Confirm the recurring tasks are registered in Solid Queue after startup:

```bash
docker compose exec rails bundle exec rails console
# In the console:
SolidQueue::RecurringTask.all.pluck(:key, :class_name)
```

Manually trigger a job and observe the result:

```bash
docker compose exec rails bundle exec rails console
# In the console:
CleanupAbandonedCartsJob.perform_now
SolidQueue::Job.order(:created_at).last
```

Check Mailpit at http://localhost:8025 after running `CleanupExpiredConductsJob.perform_now` on an environment with expired conducts to see ban-lifted emails.
