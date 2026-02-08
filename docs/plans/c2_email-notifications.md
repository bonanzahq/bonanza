# Email Notification System Implementation Plan

## Overview

Implement email notifications for Bonanza Redux based on the old Bonanza v1 system. The old system had a comprehensive email notification system for borrowers (called "lenders" in v1) and staff users. This plan outlines a simple, incremental approach to implement these features.

## Analysis of Old System

### Email Types in Bonanza v1

**LendingMailer** (for lending-related emails to borrowers):
1. `confirmation_email` - Sent when lending is completed
2. `overdue_notification_email` - Sent when items are overdue
3. `upcoming_return_notification_email` - Reminder before due date
4. `upcoming_overdue_return_notification_email` - Final reminder (day before due)
5. `banned_notification_email` - Notifies borrower they are banned
6. `duration_change_notification_email` - Notifies borrower when lending duration changes
7. `department_staffed_again_notification_email` - Notifies when department reopens

**LenderMailer** (for borrower registration/conduct emails):
1. `accept_tos_email` - Email with link to accept terms of service
2. `ban_notification_email` - Notifies borrower they received a ban
3. `ban_lifted_notification_email` - Notifies borrower ban was lifted

**UserMailer** (for staff emails):
1. `todays_returns_email` - Daily email to staff with expected returns

### When Emails Were Sent in v1

**Immediate triggers** (sent in controller actions):
- `confirmation_email` - After lending state changes to completed (lending_controller.rb:21475)
- `ban_notification_email` - When conduct (ban/warning) is created (lenders_controller.rb:21612)
- `ban_lifted_notification_email` - When conduct is removed (conducts/remove action:21630)
- `duration_change_notification_email` - When lending duration is updated (lending/update:22009)
- `accept_tos_email` - When borrower self-registers (lender model:18101)

**Scheduled tasks** (via cron/rake tasks):
- `upcoming_overdue_return_notification_email` - 2 days before due date (schedule.rb:19281, 19293)
- `upcoming_return_notification_email` - 5 days before due date (schedule.rb:19317)
- `department_staffed_again_notification_email` - When department becomes staffed (schedule.rb:19335)
- `overdue_notification_email` - When items become overdue (schedule.rb:19406)
- `banned_notification_email` - When overdue items trigger auto-ban (schedule.rb:19427)
- `todays_returns_email` - Daily at 7:30am for staff (schedule.rb:21833)
- `ban_lifted_notification_email` - When automatic bans expire (conduct model:17940)

### Terminology Mapping

| Old System (v1) | New System (Redux) |
|-----------------|-------------------|
| Lender | Borrower |
| lender_mailer.rb | borrower_mailer.rb |

## Current State in Bonanza Redux

### Existing Files
- `app/mailers/lending_mailer.rb` - Empty stub
- `app/mailers/borrower_mailer.rb` - Exists (empty stub)
- `app/mailers/application_mailer.rb` - Base mailer class

### Missing Components
1. No mailer methods implemented
2. No email view templates
3. No SMTP configuration (for production)
4. No scheduled task system for automated emails
5. No UserMailer for staff notifications

### Current TODO List References
From README.md, several TODOs mention email features:
- Confirmation email when lending is completed
- Overdue notification emails
- Return reminder emails (3-4 days before due)
- Staff daily summary emails

## Implementation Plan

### Phase 1: Basic Infrastructure Setup

**Goal**: Set up email configuration and basic structure

**Tasks**:
1. Configure SMTP for development (Mailpit)
   - Add Mailpit SMTP config to `config/environments/development.rb`:
     ```ruby
     config.action_mailer.delivery_method = :smtp
     config.action_mailer.smtp_settings = {
       address: ENV.fetch('SMTP_HOST', 'localhost'),
       port: ENV.fetch('SMTP_PORT', 1025),
       domain: ENV.fetch('SMTP_DOMAIN', 'localhost')
     }
     config.action_mailer.default_url_options = {
       host: ENV.fetch('APP_HOST', 'localhost'),
       port: ENV.fetch('APP_PORT', 3000)
     }
     ```

2. Configure SMTP for production
   - Add production SMTP config to `config/environments/production.rb`
   - Support standard SMTP environment variables
   - Enable `raise_delivery_errors` for better debugging

3. Create ApplicationMailer base class
   - Set default `from` address from ENV variable
   - Configure default URL options
   - Set up common layout

4. Create email layout template
   - Create `app/views/layouts/mailer.html.erb`
   - Create `app/views/layouts/mailer.text.erb`
   - Simple, clean German language templates

**Deliverables**:
- Email configuration in all environments
- Base mailer class with sensible defaults
- Email layout templates

### Phase 2: High-Priority Borrower Emails

**Goal**: Implement most important borrower-facing emails

**Priority Order** (based on v1 usage and user impact):
1. Confirmation email (immediate feedback)
2. Overdue notification email (critical for returns)
3. Upcoming return reminder (prevents overdue)

**Implementation Steps per Email**:

**2.1 Confirmation Email**
- Add method to `LendingMailer`:
  ```ruby
  def confirmation_email(lending)
    @lending = lending
    @borrower = @lending.borrower
    @user = @lending.user
    mail(
      to: @borrower.email,
      reply_to: "#{@user.full_name} <#{@user.email}>",
      subject: 'Ausleihbestätigung'
    )
  end
  ```
- Create views:
  - `app/views/lending_mailer/confirmation_email.html.erb`
  - `app/views/lending_mailer/confirmation_email.text.erb`
- Include in view:
  - Borrower name
  - List of borrowed items with UIDs
  - Due date
  - Department contact info
  - Link to view/print lending agreement
- Trigger: After lending state changes to `completed` in `LendingController#update`

**2.2 Overdue Notification Email**
- Add method to `LendingMailer`:
  ```ruby
  def overdue_notification_email(lending)
    @lending = lending
    @overdue_line_items = lending.line_items.where(returned_at: nil)
    @borrower = @lending.borrower
    @user = @lending.user
    mail(
      to: @borrower.email,
      reply_to: "#{@user.full_name} <#{@user.email}>",
      subject: 'Verwarnung: Leihfrist überschritten'
    )
  end
  ```
- Create HTML and text views
- Include:
  - Warning message
  - List of overdue items
  - Days overdue per item
  - Return instructions
  - Consequences of continued overdue status
- Trigger: Scheduled rake task (daily check)

**2.3 Upcoming Return Reminder Email**
- Add method to `LendingMailer`:
  ```ruby
  def upcoming_return_notification_email(lending)
    @lending = lending
    @borrower = @lending.borrower
    @user = @lending.user
    mail(
      to: @borrower.email,
      reply_to: "#{@user.full_name} <#{@user.email}>",
      subject: "Anstehende Rückgabe in der #{@lending.department.name}"
    )
  end
  ```
- Create HTML and text views
- Include:
  - Friendly reminder
  - Due date
  - List of items
  - Department hours/contact
- Trigger: Scheduled rake task (5 days before due)

**Deliverables**:
- Three implemented mailer methods
- Six view templates (HTML + text for each)
- Integration in lending workflow
- Manual testing checklist

### Phase 3: Scheduled Email System

**Goal**: Set up automated email delivery via scheduled tasks in a dedicated scheduler container

**Background**: Running cron inside Docker containers is problematic (restarts lose config, logging issues, multiple processes). Instead, we use a dedicated scheduler container running clockwork.

**Tasks**:

1. Add clockwork gem to Gemfile
   ```ruby
   gem 'clockwork'
   ```

2. Create rake tasks for email notifications
   - File: `lib/tasks/notifications.rake`
   - Namespace: `bonanza:notifications`
   - Tasks:
     - `send_upcoming_return_reminders` - 5 days before due
     - `send_upcoming_overdue_reminders` - 1 day before due
     - `send_overdue_notifications` - Items now overdue
     - `send_daily_staff_summary` - Daily returns summary
     - `check_expired_conducts` - Remove expired bans

3. Implement rake task logic
   ```ruby
   namespace :bonanza do
     namespace :notifications do
       desc "Send reminders for lendings due in 5 days"
       task send_upcoming_return_reminders: :environment do
         # Find lendings due in 5 days that haven't been returned
         lendings = Lending.where(returned_at: nil)
           .where("DATE(lent_at + INTERVAL duration DAY) = ?", 5.days.from_now.to_date)

         lendings.each do |lending|
           LendingMailer.upcoming_return_notification_email(lending).deliver_later
         end
       end

       desc "Send reminders for lendings due tomorrow"
       task send_upcoming_overdue_reminders: :environment do
         lendings = Lending.where(returned_at: nil)
           .where("DATE(lent_at + INTERVAL duration DAY) = ?", 1.day.from_now.to_date)

         lendings.each do |lending|
           LendingMailer.upcoming_overdue_return_notification_email(lending).deliver_later
         end
       end

       desc "Send overdue notifications"
       task send_overdue_notifications: :environment do
         lendings = Lending.where(returned_at: nil)
           .where("DATE(lent_at + INTERVAL duration DAY) < ?", Date.today)

         lendings.each do |lending|
           LendingMailer.overdue_notification_email(lending).deliver_later
         end
       end

       desc "Send daily returns summary to staff"
       task send_daily_staff_summary: :environment do
         Department.find_each do |department|
           lendings = department.lendings
             .where(returned_at: nil)
             .where("DATE(lent_at + INTERVAL duration DAY) = ?", Date.today)

           next if lendings.empty?

           department.users.active.each do |user|
             UserMailer.todays_returns_email(lendings, user).deliver_later
           end
         end
       end

       desc "Remove expired automatic conducts and notify"
       task check_expired_conducts: :environment do
         Conduct.remove_old_automatic_conducts
       end
     end
   end
   ```

4. Create clockwork configuration file
   - File: `config/clock.rb`
   ```ruby
   require 'clockwork'
   require './config/boot'
   require './config/environment'

   module Clockwork
     # Log to stdout for Docker
     configure do |config|
       config[:logger] = Logger.new(STDOUT)
     end

     every(1.day, 'send_upcoming_return_reminders', at: '07:00', tz: 'Europe/Berlin') do
       puts "[#{Time.now}] Running: send_upcoming_return_reminders"
       Rake::Task['bonanza:notifications:send_upcoming_return_reminders'].execute
     end

     every(1.day, 'send_upcoming_overdue_reminders', at: '07:15', tz: 'Europe/Berlin') do
       puts "[#{Time.now}] Running: send_upcoming_overdue_reminders"
       Rake::Task['bonanza:notifications:send_upcoming_overdue_reminders'].execute
     end

     every(1.day, 'send_overdue_notifications', at: '07:30', tz: 'Europe/Berlin') do
       puts "[#{Time.now}] Running: send_overdue_notifications"
       Rake::Task['bonanza:notifications:send_overdue_notifications'].execute
     end

     every(1.day, 'send_daily_staff_summary', at: '07:30', tz: 'Europe/Berlin') do
       puts "[#{Time.now}] Running: send_daily_staff_summary"
       Rake::Task['bonanza:notifications:send_daily_staff_summary'].execute
     end

     every(1.day, 'check_expired_conducts', at: '20:00', tz: 'Europe/Berlin') do
       puts "[#{Time.now}] Running: check_expired_conducts"
       Rake::Task['bonanza:notifications:check_expired_conducts'].execute
     end
   end
   ```

5. Add scheduler container to docker-compose.yml
   ```yaml
   services:
     # ... existing services ...

     scheduler:
       build:
         context: .
         dockerfile: Dockerfile
       command: bundle exec clockwork config/clock.rb
       depends_on:
         - db
         - elasticsearch
       environment:
         - RAILS_ENV=${RAILS_ENV:-production}
         - DATABASE_URL=${DATABASE_URL}
         - ELASTICSEARCH_URL=http://elasticsearch:9200
         - SMTP_HOST=${SMTP_HOST}
         - SMTP_PORT=${SMTP_PORT}
         - SMTP_DOMAIN=${SMTP_DOMAIN}
         - SMTP_USERNAME=${SMTP_USERNAME}
         - SMTP_PASSWORD=${SMTP_PASSWORD}
         - APP_HOST=${APP_HOST}
         - APP_PORT=${APP_PORT}
         - APP_PROTOCOL=${APP_PROTOCOL}
         - DEFAULT_FROM_EMAIL=${DEFAULT_FROM_EMAIL}
       networks:
         - bonanza_network
       restart: unless-stopped
       # Logs go to stdout, visible via docker-compose logs scheduler
   ```

6. Document scheduling system
   - How to view scheduler logs: `docker-compose logs -f scheduler`
   - How to test scheduled tasks manually: `docker-compose exec rails bundle exec rake bonanza:notifications:send_upcoming_return_reminders`
   - How to restart scheduler: `docker-compose restart scheduler`
   - Timezone configuration (defaults to Europe/Berlin)

**Deliverables**:
- clockwork gem added to Gemfile
- Rake tasks for all scheduled emails
- config/clock.rb with all scheduled tasks
- Scheduler container in docker-compose.yml
- Documentation for monitoring and testing

---

## CRITICAL: Background Job Requirement

**All mailer calls MUST use `.deliver_later`.** Synchronous delivery blocks HTTP requests, causes timeouts during bulk sends (100+ emails), provides no retry logic, and risks triggering spam filters.

**Required dependency:** Complete plan `c1_background-jobs.md` before deploying email functionality.

**Queue assignments:**
- `:critical` - confirmation emails, password resets (user expects immediate)
- `:default` - return reminders, overdue notifications
- `:low` - daily staff summaries, batch operations

See `docs/plans/c1_background-jobs.md` for full implementation details.

---

### Phase 4: Additional Borrower Emails

**Goal**: Implement remaining borrower notification emails

**Emails to implement**:

1. **Upcoming Overdue Reminder** (final warning)
   - 1 day before due date
   - More urgent tone than 5-day reminder
   - Emphasize consequences

2. **Duration Change Notification**
   - Sent when staff changes lending duration
   - Show old vs new due date
   - Include reason if provided

3. **Department Staffed Again Notification**
   - Sent when department reopens after being unstaffed
   - Inform borrowers they can return items
   - Include new department hours

4. **Ban Notification** (automatic)
   - Sent when system automatically bans for overdue
   - Different from conduct ban notification
   - Include appeal process

**Implementation**: Same pattern as Phase 2
- Mailer method
- HTML + text views
- Integration point
- Testing

**Deliverables**:
- Four additional mailer methods
- Eight view templates
- Integration in lending workflow

### Phase 5: Borrower Account Emails

**Goal**: Implement borrower registration and conduct emails

**Create BorrowerMailer** with:

1. **Accept TOS Email**
   - Sent after self-registration
   - Contains link with token to confirm email and accept terms
   - Link format: `/borrowers/confirm_email?token=#{@borrower.tos_token}`
   - Includes PDF/link to terms of service

2. **Ban Notification Email** (manual by staff)
   - Sent when staff creates a conduct (warning/ban)
   - Include reason from staff
   - Duration (if temporary)
   - Appeal process

3. **Ban Lifted Notification Email**
   - Sent when staff removes ban or ban expires automatically
   - Welcoming tone
   - Remind of terms of service

**Implementation**:
- Create `BorrowerMailer` class
- Three mailer methods
- Six view templates
- Integration with:
  - `BorrowersController#self_register`
  - `BorrowersController#confirm_email`
  - `ConductsController` (create/destroy)
  - `Conduct.remove_old_automatic_conducts` (class method)

**Deliverables**:
- BorrowerMailer with 3 methods
- Six view templates
- Email confirmation flow working

### Phase 6: Staff Emails

**Goal**: Implement staff notification emails

**Create UserMailer** with:

1. **Today's Returns Email**
   - Sent daily at 7:30am to all staff in department
   - Lists all lendings due to be returned today
   - Grouped by department
   - Quick overview: total items, total lendings
   - Links to each lending detail page

**Implementation**:
- Create `UserMailer` class
- Create mailer method:
  ```ruby
  def todays_returns_email(lendings, user)
    @lendings = lendings
    @line_items_count = @lendings.sum { |l| l.line_items.count }
    @user = user
    mail(to: @user.email, subject: 'Was heute zurückgegeben wird')
  end
  ```
- Create views (HTML + text)
- Add rake task to send to all active staff per department
- Consider adding user preference to opt out

**Deliverables**:
- UserMailer class
- Two view templates
- Rake task for daily sending
- User preference model (optional)

## Technical Considerations

### Email Content Best Practices

1. **German Language**
   - All emails in German (matching UI)
   - Use formal "Sie" for professional tone
   - Clear, concise messaging

2. **Accessibility**
   - Always provide both HTML and text versions
   - Use semantic HTML
   - Test with screen readers

3. **Mobile-Friendly**
   - Responsive email templates
   - Large touch-friendly links/buttons
   - Test on mobile email clients

4. **Required Information in Every Email**
   - Clear subject line
   - Sender department/staff contact
   - Action required (if any)
   - Relevant dates
   - Department contact information
   - Reply-to set to relevant staff member

### Database Considerations

**Email Tracking** (optional enhancement):
- Track email delivery status
- Track email opens (via tracking pixel)
- Track link clicks
- Store in `email_logs` table
- Helps debug delivery issues

**Notification Preferences** (optional enhancement):
- Allow borrowers to opt out of reminders (but not critical emails)
- Store preferences in `borrower` table
- UI in borrower settings

### Error Handling

1. **Failed Delivery**
   - Log all failed deliveries
   - Retry logic (via Sidekiq or similar)
   - Alert staff of critical email failures
   - Fallback to SMS for urgent notifications (future)

2. **Invalid Email Addresses**
   - Validate email format before sending
   - Handle bounces appropriately
   - Mark borrower emails as invalid
   - Require email update before next lending

3. **Rate Limiting**
   - Implement sending delays for bulk emails
   - Avoid triggering spam filters
   - Use background jobs for scheduled tasks

### Testing Strategy

1. **Unit Tests**
   - Test each mailer method
   - Verify correct recipient, subject, body content
   - Test with different locales if needed

2. **Integration Tests**
   - Test email triggered from controller actions
   - Test scheduled task execution
   - Verify email delivery in test mode

3. **Manual Testing**
   - Use Mailpit in development to preview all emails
   - Test email rendering in multiple clients:
     - Gmail
     - Outlook
     - Apple Mail
     - Mobile clients
   - Test reply-to functionality

4. **Mailer Previews**
   - Create preview classes for all mailers
   - Access at `/rails/mailers` in development
   - Example: `test/mailers/previews/lending_mailer_preview.rb`

### Performance Considerations

1. **Background Jobs** (MANDATORY - see plan c1)
   - Use Solid Queue via ActiveJob for email sending
   - All emails MUST use `.deliver_later` not `.deliver_later`
   - See `docs/plans/c1_background-jobs.md` for implementation

2. **Database Queries**
   - Optimize queries for scheduled tasks
   - Use `includes` to avoid N+1 queries
   - Add appropriate indexes for date-based queries

3. **Scheduled Task Timing**
   - Spread scheduled tasks across different times
   - Avoid running multiple heavy tasks simultaneously
   - Consider timezone of users (if applicable)

## Migration from Old System

**Data Compatibility**:
- Old system used "lender" terminology, new uses "borrower"
- Email templates should match old system's tone and content
- Preserve email addresses during migration
- Test emails with migrated data

**Gradual Rollout**:
1. Start with confirmation emails only
2. Add reminders after monitoring confirmation delivery
3. Add overdue notifications once confident in system
4. Finally add automated bans/conducts

## Environment Variables Required

```env
# SMTP Configuration
SMTP_HOST=mailpit              # Development: mailpit, Production: smtp.example.com
SMTP_PORT=1025                 # Development: 1025, Production: 587
SMTP_DOMAIN=localhost          # Development: localhost, Production: example.com
SMTP_USERNAME=                 # Production only
SMTP_PASSWORD=                 # Production only
SMTP_AUTHENTICATION=plain      # Production: plain, login, etc
SMTP_ENABLE_STARTTLS=true     # Production: true

# Application URLs (for links in emails)
APP_HOST=localhost             # Development: localhost, Production: bonanza.example.com
APP_PORT=3000                  # Development: 3000, Production: 443
APP_PROTOCOL=http              # Development: http, Production: https

# Email Defaults
DEFAULT_FROM_EMAIL=bonanza@fh-potsdam.de
DEFAULT_REPLY_TO_EMAIL=support@fh-potsdam.de
```

## Success Criteria

Each phase should meet these criteria before moving to next:

1. **Phase 1**:
   - Mailpit receives test emails in development
   - Production SMTP configuration documented

2. **Phase 2**:
   - All three email types send successfully
   - Email content reviewed and approved by stakeholders
   - Borrowers can receive and act on emails

3. **Phase 3**:
   - Scheduled tasks run automatically
   - Rake tasks can be triggered manually
   - Logs show successful execution

4. **Phase 4-6**:
   - All email types implemented
   - Mailer previews working for all emails
   - Email templates tested in multiple clients
   - No email-related errors in logs

## Future Enhancements

**Not included in initial implementation but possible later**:

1. **Email Templates System**
   - Allow staff to customize email templates via admin UI
   - Use Liquid templating or similar
   - Preview before sending

2. **SMS Notifications**
   - Add phone number to borrowers
   - SMS for critical notifications (overdue, bans)
   - Use Twilio or similar service

3. **In-App Notifications**
   - Notification bell in UI
   - Show recent notifications
   - Mark as read functionality

4. **Digest Emails**
   - Weekly summary for borrowers with active lendings
   - Monthly summary for staff with statistics

5. **Email Analytics**
   - Track open rates
   - Track click rates
   - A/B test subject lines

6. **Multi-Language Support**
   - Support English in addition to German
   - User language preference
   - Language detection from browser

## Timeline Estimate

**Phase 1**: 1-2 days
- SMTP configuration
- Base mailer setup
- Layout templates

**Phase 2**: 3-4 days
- Three mailer methods
- Six view templates
- Integration and testing

**Phase 3**: 2-3 days
- Rake tasks
- Scheduling setup
- Testing

**Phase 4**: 3-4 days
- Four additional emails
- Integration

**Phase 5**: 2-3 days
- BorrowerMailer
- Email confirmation flow

**Phase 6**: 1-2 days
- UserMailer
- Staff daily email

**Total**: 12-18 days of development work

**Note**: Timeline assumes one developer working full-time. Testing and refinement may add additional time.

## References

- Old Bonanza v1 mailers: `docs/repomix-output-bonanza_v1.xml`
- Rails Action Mailer Guide: https://guides.rubyonrails.org/action_mailer_basics.html
- Email on Acid (testing): https://www.emailonacid.com/
- Really Good Emails (inspiration): https://reallygoodemails.com/
