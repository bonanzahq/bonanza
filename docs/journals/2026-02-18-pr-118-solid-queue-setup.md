# PR #118: Solid Queue Setup

Branch: `feat/solid-queue-setup`
PR: https://github.com/bonanzahq/bonanza/pull/118
Merged: 2026-02-18

## Summary

Introduces Solid Queue as the Active Job backend, replacing the default inline adapter in development and production. Adds a dedicated worker container, a database migration for the Solid Queue tables, and configures retry/discard behaviour on the base job class.

## What changed

| File | Change |
|------|--------|
| `Gemfile` | Added `solid_queue` 1.3.1 |
| `config/application.rb` | Set `config.active_job.queue_adapter = :solid_queue` as the global default |
| `config/environments/production.rb` | Set `config.active_job.queue_adapter = :solid_queue` (explicit production override) and configured SMTP/mailer settings |
| `config/environments/test.rb` | Set `config.active_job.queue_adapter = :test` so tests use the in-memory adapter |
| `config/queue.yml` | New file — defines dispatchers and three worker pools: `critical` (3 threads, 0.1 s poll), `default` (5 threads, 0.5 s poll), `low` (2 threads, 2 s poll) |
| `app/jobs/application_job.rb` | New file — base job class with retry logic for `ActiveRecord::Deadlocked`, `Net::SMTPServerBusy`, `Net::OpenTimeout`, `Errno::ECONNREFUSED`, and discard on `ActiveJob::DeserializationError` |
| `app/models/borrower.rb` | `send_confirmation_pending_email` now calls `deliver_later` (enqueued via Solid Queue) instead of `deliver_now` |
| `docker-compose.yml` | Added `worker` service running `bundle exec rake solid_queue:start`, sharing the app image, with `SKIP_REINDEX: "true"` and 256 MB memory limit |
| `docker-compose.override.yml` | Added `worker` service override for development: local build, volume mounts, dev environment variables |
| `docker-entrypoint.sh` | Added `SKIP_REINDEX` guard — reindexing is skipped when the variable is set (prevents worker container from triggering a redundant ES reindex on startup) |
| `db/migrate/20260218143600_add_solid_queue_tables.rb` | Creates all Solid Queue tables: `solid_queue_jobs`, `solid_queue_blocked_executions`, `solid_queue_claimed_executions`, `solid_queue_failed_executions`, `solid_queue_pauses`, `solid_queue_processes`, `solid_queue_ready_executions`, `solid_queue_recurring_executions`, `solid_queue_recurring_tasks`, `solid_queue_scheduled_executions`, `solid_queue_semaphores` with foreign keys and indexes |
| `test/jobs/application_job_test.rb` | New file — tests that a concrete job can be enqueued and targets the `default` queue |
| `test/mailers/borrower_mailer_test.rb` | Added test verifying `confirm_email` is enqueued via `deliver_later` |

## Why

The application sends transactional email. Running mailer delivery synchronously in the web process blocks request handling and provides no retry on transient SMTP failures. Solid Queue stores jobs in PostgreSQL (the existing database), avoiding an extra dependency like Redis. The separate worker container isolates background processing from the web process and can be scaled independently.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/jobs/application_job_test.rb` | `job can be enqueued` | A concrete subclass of `ApplicationJob` can be enqueued with `perform_later` using the test adapter |
| | `job is enqueued to the default queue` | The job is placed on the `default` queue |
| `test/mailers/borrower_mailer_test.rb` | `confirm_email is enqueued with deliver_later` | `BorrowerMailer#confirm_email` enqueues exactly one email when called with `deliver_later` |

## Manual verification

Check the worker process is running in Docker:

```bash
docker compose exec -T worker sh -c "ps aux | grep solid_queue"
```

Verify the Solid Queue tables exist in the database:

```bash
docker compose exec -T db psql -U postgres bonanza_redux_development -c "\dt solid_queue_*"
```

Run the job tests:

```bash
docker compose exec rails bundle exec rails test test/jobs/application_job_test.rb
```

Trigger a confirmation email from the Rails console and confirm it appears in the queue:

```bash
docker compose exec rails bundle exec rails console
# In the console:
borrower = Borrower.first
borrower.send_confirmation_pending_email
SolidQueue::Job.last
```

Check Mailpit (dev only) at http://localhost:8025 to see the delivered email once the worker processes it.
