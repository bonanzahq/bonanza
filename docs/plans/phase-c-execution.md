# Phase C Execution Plan

## Overview

Phase C implements feature gaps between Bonanza v1 and Redux:
- c1+c2: Background Jobs + Email Notifications
- c3: Conduct System (warnings, auto-ban escalation)
- c4: GDPR & Data Retention

## Architecture Decisions

- **Job backend**: Solid Queue (Rails 8 default, PostgreSQL-backed, no Redis)
- **Scheduling**: Solid Queue recurring tasks (built into dispatcher, no clockwork/extra container)
- **Email delivery**: All `.deliver_later` via ActiveJob (no synchronous delivery)
- **Rate limiting**: Deferred (not needed at current university scale)

## Execution Phases

### Phase 0: Foundation (1 worker, blocks everything)

**Task 0: Solid Queue Setup** (`feat/solid-queue-setup`)
- Install solid_queue gem, run migrations
- Configure ActiveJob adapter in all environments
- Create `config/solid_queue.yml` with queues (critical, default, low)
- Configure ApplicationJob retry logic
- Convert existing `.deliver_now` to `.deliver_later`
- Add worker container to docker-compose.yml
- Tests: verify job enqueue/process, deliver_later works

### Phase 1: Parallel (4 workers)

**Task 1A: LendingMailer** (`feat/lending-mailer`)
- Implement 6 methods: confirmation_email, overdue_notification_email,
  upcoming_return_notification_email, upcoming_overdue_return_notification_email,
  duration_change_notification_email, department_staffed_again_notification_email
- Create HTML + text views for each (12 templates)
- Mailer tests

**Task 1B: BorrowerMailer Updates** (`feat/borrower-mailer-updates`)
- Add text templates for existing 3 HTML emails
- Add auto_ban_notification_email method + views
- Mailer tests

**Task 1C: UserMailer** (`feat/user-mailer`)
- Create UserMailer with todays_returns_email
- HTML + text views
- Mailer tests

**Task 1D: Conduct Model Logic** (`feat/conduct-expiration`)
- Replace commented-out remove_old_automatic_conducts with working PostgreSQL queries
- Add helper methods: expired?, days_remaining, expiration_date, automatic?
- Implement warning escalation (2 warnings in department = auto-ban)
- Model-only, no email wiring (that's Phase 2)
- Model tests

### Phase 1.5: Sequential dependency

**Task 1E: Lending Notifications** (`feat/lending-notifications`)
- Uncomment/modernize notification methods in lending.rb
- Fix terminology (lender -> borrower, LenderMailer -> appropriate mailer)
- Convert all .deliver_now to .deliver_later
- Uncomment duration change email in lending_controller.rb
- Depends on: Task 1A (uses LendingMailer method signatures)

### Phase 2: Integration (3 workers)

**Task 2A: Scheduled Jobs** (`feat/scheduled-jobs`)
- Create ActiveJob classes for all recurring tasks:
  - SendOverdueNotificationsJob
  - SendUpcomingReturnRemindersJob
  - SendUpcomingOverdueRemindersJob
  - SendStaffDailyReturnsJob
  - CleanupExpiredConductsJob
- Add recurring_tasks config to solid_queue.yml
- No extra container needed (dispatcher handles scheduling)
- Job tests

**Task 2B: Conduct Email Wiring** (`feat/conduct-email-wiring`)
- Wire conduct creation/deletion to email delivery via .deliver_later
- Add conduct expiration info to borrower views
- Dispatch auto-ban email when escalation triggers
- Depends on: 1B (auto_ban email), 1D (conduct model logic)

### Phase 3: GDPR (1 then 2 workers)

**Task 3A: GDPR Model Methods** (`feat/gdpr-anonymize`)
- Add anonymize! to Borrower and User models
- Add export_personal_data to Borrower
- Add request_deletion! to Borrower
- Model tests

**Task 3B: GDPR Rake Tasks** (`feat/gdpr-rake-tasks`) — after 3A
- Scheduled cleanup tasks as ActiveJob classes
- Add to solid_queue.yml recurring_tasks
- Job tests

**Task 3C: GDPR Controller + Routes** (`feat/gdpr-data-export`) — after 3A
- Data export endpoint
- Manual deletion request handling
- Controller tests

### Phase 4: Final (1 worker)

**Task 4: GDPR Audit Logging** (`feat/gdpr-audit`)
- GdprAuditable concern for structured audit logging
- Include in Borrower and User models
- Tests

## Merge Order

1. Task 0 (foundation)
2. Tasks 1A, 1B, 1C, 1D (parallel)
3. Task 1E (after 1A)
4. Tasks 2A, 2B (parallel, after Phase 1)
5. Task 3A
6. Tasks 3B, 3C (parallel, after 3A)
7. Task 4 (last)

## Risks

- **db/schema.rb conflicts**: Only Phase 0 adds migrations. Later phases avoid schema changes.
- **Email template consistency**: Task 1A establishes the pattern, others follow.
- **Commented-out code**: Task 1E must carefully translate old names, not just uncomment.
