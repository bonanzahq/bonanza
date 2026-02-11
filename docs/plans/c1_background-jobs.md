# Background Job Processing Plan

## Problem Statement

The email notification system (plan c2) uses synchronous delivery (`.deliver_now`). This causes:

- **Request blocking** - User waits while email sends
- **Timeouts** - Bulk operations (100+ overdue notifications) will timeout
- **No retry logic** - Failed emails are lost
- **No rate limiting** - Risk of triggering spam filters

## Current State

```ruby
# borrower.rb:39 - synchronous
BorrowerMailer.with(borrower: self).confirm_email.deliver_now
```

Clockwork (from email plan) runs rake tasks that send emails synchronously in a loop - still blocking, just in a background container.

## Solution: ActiveJob with Solid Queue

Rails 8 includes Solid Queue as the default job backend. Database-backed (PostgreSQL), no Redis required.

### Why Solid Queue over Sidekiq?

| Aspect | Solid Queue | Sidekiq |
|--------|-------------|---------|
| Dependencies | PostgreSQL only | Requires Redis |
| Future | Rails 8 default | Third-party |
| Complexity | Simple | More features |
| Scale | < 10k jobs/hour | Millions/hour |
| Dashboard | Basic | Excellent |

**Recommendation:** Solid Queue - simpler infrastructure, good enough for our scale.

## Implementation Plan

### Phase 1: Add Solid Queue

**Tasks:**

1. Add gem to Gemfile (Solid Queue is a default Rails 8 component; if on Rails 8, it may already be included)
   ```ruby
   gem 'solid_queue', '~> 1.0'
   ```

2. Install and run migrations
   ```bash
   bundle install
   bin/rails solid_queue:install
   bin/rails db:migrate
   ```

3. Configure ActiveJob adapter
   ```ruby
   # config/application.rb
   config.active_job.queue_adapter = :solid_queue
   ```

4. Configure Solid Queue
   ```yaml
   # config/solid_queue.yml
   default: &default
     dispatchers:
       - polling_interval: 1
         batch_size: 500
     workers:
       - queues: "*"
         threads: 3
         processes: 1
         polling_interval: 0.1

   development:
     <<: *default

   production:
     <<: *default
     workers:
       - queues: [critical, default, low]
         threads: 5
         processes: 2
         polling_interval: 0.1
   ```

### Phase 2: Convert Mailers to Async

**Change all `.deliver_now` to `.deliver_later`:**

```ruby
# Before (synchronous)
BorrowerMailer.with(borrower: self).confirm_email.deliver_now

# After (async via ActiveJob)
BorrowerMailer.with(borrower: self).confirm_email.deliver_later
```

**Files to update:**
- `app/models/borrower.rb:39`
- All mailer calls in controllers (after implementing email plan)
- All scheduled task mailer calls

### Phase 3: Add Job Queues with Priorities

**Queue structure:**

| Queue | Purpose | Examples |
|-------|---------|----------|
| `critical` | User-facing, immediate feedback | Confirmation emails, password resets |
| `default` | Important but not time-sensitive | Return reminders, overdue notifications |
| `low` | Bulk operations, reports | Daily staff summaries, batch notifications |

**Usage:**
```ruby
LendingMailer.confirmation_email(lending).deliver_later(queue: :critical)
LendingMailer.overdue_notification_email(lending).deliver_later(queue: :default)
UserMailer.todays_returns_email(lendings, user).deliver_later(queue: :low)
```

### Phase 4: Add Retry Logic

**Configure base job class:**
```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  # Retry with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Email-specific retries
  retry_on Net::SMTPServerBusy, wait: 1.minute, attempts: 5
  retry_on Net::SMTPAuthenticationError, attempts: 1
  retry_on Net::OpenTimeout, wait: 10.seconds, attempts: 3
  retry_on Errno::ECONNREFUSED, wait: 30.seconds, attempts: 3

  # Don't retry deserialization errors
  discard_on ActiveJob::DeserializationError

  # Log failures after all retries exhausted
  after_discard do |job, error|
    Rails.logger.error(
      "Job permanently failed: #{job.class.name} " \
      "args=#{job.arguments.inspect} " \
      "error=#{error.message}"
    )
    Sentry.capture_exception(error) if defined?(Sentry)
  end
end
```

### Phase 5: Rate Limiting for Bulk Sends

**Problem:** Sending 200 overdue emails at once may trigger spam filters.

**Solution:** Spread bulk emails over time:

```ruby
# lib/tasks/notifications.rake
namespace :bonanza do
  namespace :notifications do
    desc "Send overdue notifications with rate limiting"
    task send_overdue_notifications: :environment do
      lendings = Lending.overdue.where(returned_at: nil)

      lendings.each_with_index do |lending, index|
        # Stagger delivery: 1 email per 3 seconds = 20/minute = 1200/hour
        LendingMailer.overdue_notification_email(lending)
          .deliver_later(wait: (index * 3).seconds, queue: :default)
      end

      puts "Queued #{lendings.count} overdue notifications"
    end
  end
end
```

### Phase 6: Docker Integration

**Add worker container to docker-compose:**

```yaml
# docker-compose.yml
services:
  # ... existing services ...

  worker:
    build:
      context: .
      dockerfile: Dockerfile
    command: bundle exec rake solid_queue:start
    depends_on:
      - db
    environment:
      - RAILS_ENV=${RAILS_ENV:-production}
      - DATABASE_URL=${DATABASE_URL}
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_DOMAIN=${SMTP_DOMAIN}
    networks:
      - bonanza_network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

**Note:** This works alongside the `scheduler` container. Clockwork triggers scheduled tasks, which queue jobs to Solid Queue, which the worker processes.

### Phase 7: Monitoring

**Add job metrics logging:**

```ruby
# config/initializers/solid_queue.rb
ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  job = event.payload[:job]

  Rails.logger.info(
    "Job completed: #{job.class.name} " \
    "queue=#{job.queue_name} " \
    "duration=#{event.duration.round(2)}ms"
  )
end
```

**Health check for worker:**
```ruby
# Add to health controller
def worker_healthy?
  stale_jobs = SolidQueue::Job.where(
    "scheduled_at < ? AND finished_at IS NULL",
    30.minutes.ago
  ).count

  stale_jobs < 100
end
```

## Migration Strategy

1. **Add Solid Queue** (no behavior change) - install, migrate, configure
2. **Convert non-critical emails first** - staff summaries, reminders
3. **Convert critical emails** - confirmations, password resets
4. **Add rate limiting** - for bulk operations
5. **Monitor** - watch for delivery issues

## Testing

```ruby
# config/environments/test.rb
config.active_job.queue_adapter = :test
```

```ruby
# Example test
class LendingMailerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "confirmation email is queued" do
    lending = create(:lending, :completed)

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      LendingMailer.confirmation_email(lending).deliver_later
    end
  end
end
```

## Deliverables

- [ ] Solid Queue gem installed and configured
- [ ] Database migrations run
- [ ] All `.deliver_now` converted to `.deliver_later`
- [ ] Queue priorities configured (critical, default, low)
- [ ] Retry logic implemented
- [ ] Rate limiting for bulk sends
- [ ] Docker worker container configured
- [ ] Health checks for worker
- [ ] Monitoring/logging in place
- [ ] Tests updated for async delivery

## Dependencies

- **Requires:** PostgreSQL (for Solid Queue tables)
- **Updates:** Email notification plan (c2) - mailer calls change
- **Updates:** Containerization plan (b1) - add worker container
- **Integrates with:** Error handling plan (b2) - job failure reporting

