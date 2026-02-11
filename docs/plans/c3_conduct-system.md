# Conduct System Completion Plan

## Problem Statement

The conduct (warning/ban) system is partially implemented:

1. `conduct.rb:20-27` has **commented-out** `remove_old_automatic_conducts` method
2. Email plan references `Conduct.remove_old_automatic_conducts` which doesn't work
3. README mentions "2 x warning → note & email" but escalation isn't implemented
4. No automatic ban expiration logic

## Current State

### Commented-Out Code in conduct.rb

```ruby
# this will be invoked by a cron job each day at 7:30pm. Needs rework!
# def self.remove_old_automatic_conducts
#   conducts = Conduct.where(permanent: false, duration: nil)
#     .where("DATE(created_at) = #{PortableQuery.date_add(PortableQuery.today, '-60')}")
#     .destroy_all
#   conducts += Conduct.where.not(permanent: true, duration: nil)
#     .where("DATE(#{PortableQuery.date_add('DATE(created_at)', 'duration')}) = #{PortableQuery.today}")
#     .destroy_all
#   conducts.each do |conduct|
#     LenderMailer.ban_lifted_notification_email(conduct).deliver_now
#   end
# end
```

**Issues:**
- Uses `PortableQuery` which doesn't exist in Redux
- Query logic is incorrect
- Uses `.deliver_now` (should be `.deliver_later`)

### Conduct Model Structure

```ruby
enum kind: { warned: 0, banned: 1 }

# Fields:
# - kind: :warned or :banned
# - reason: text (required)
# - duration: integer (days, optional)
# - permanent: boolean
# - borrower_id, department_id, lending_id, user_id
```

## Implementation Plan

### Phase 1: Fix Expiration Logic

**Replace commented code with working implementation:**

```ruby
# app/models/conduct.rb

# Remove conducts that have expired based on their duration
def self.remove_expired_conducts
  # Find non-permanent conducts where duration has passed
  expired = where(permanent: false)
    .where.not(duration: nil)
    .where('created_at + (duration * INTERVAL \'1 day\') < ?', Time.current)

  count = 0
  expired.find_each do |conduct|
    # Store data before destroy for email
    borrower = conduct.borrower
    conduct_data = conduct.attributes.slice('kind', 'reason', 'department_id')

    conduct.destroy

    # Send notification (async via background jobs plan)
    BorrowerMailer.ban_lifted_notification_email(borrower, conduct_data)
      .deliver_later(queue: :default)

    count += 1
  end

  Rails.logger.info("Removed #{count} expired conducts")
  count
end

# Remove automatic conducts (no user_id) that are 60+ days old
def self.remove_stale_automatic_conducts
  stale = where(permanent: false, duration: nil, user_id: nil)
    .where('created_at < ?', 60.days.ago)

  count = 0
  stale.find_each do |conduct|
    borrower = conduct.borrower
    conduct_data = conduct.attributes.slice('kind', 'reason', 'department_id')

    conduct.destroy

    BorrowerMailer.ban_lifted_notification_email(borrower, conduct_data)
      .deliver_later(queue: :default)

    count += 1
  end

  Rails.logger.info("Removed #{count} stale automatic conducts")
  count
end

# Combined cleanup method for scheduler
def self.cleanup_expired
  expired = remove_expired_conducts
  stale = remove_stale_automatic_conducts
  { expired: expired, stale: stale }
end
```

### Phase 2: Add Helper Methods

```ruby
# app/models/conduct.rb

def expired?
  return false if permanent?
  return false if duration.nil?
  created_at + duration.days < Time.current
end

def days_remaining
  return nil if permanent?
  return nil if duration.nil?
  remaining = ((created_at + duration.days - Time.current) / 1.day).to_i
  [remaining, 0].max
end

def expiration_date
  return nil if permanent?
  return nil if duration.nil?
  created_at + duration.days
end

def automatic?
  user_id.nil?
end

def description
  if permanent?
    "Dauerhaft"
  elsif duration.present?
    "#{duration} Tage (noch #{days_remaining} übrig)"
  else
    "Automatisch (60 Tage)"
  end
end
```

### Phase 3: Warning Escalation

**Implement "2 warnings → ban" rule:**

```ruby
# app/models/conduct.rb

# Check if borrower should be auto-banned after multiple warnings
def self.check_warning_escalation(borrower, department)
  warnings = borrower.conducts.where(department: department, kind: :warned)
  warning_count = warnings.count

  return unless warning_count >= 2

  # Check if already banned
  return if borrower.conducts.where(department: department, kind: :banned).exists?

  # Create automatic ban
  ban = Conduct.create!(
    borrower: borrower,
    department: department,
    kind: :banned,
    reason: "Automatische Sperre nach #{warning_count} Verwarnungen",
    permanent: false,
    duration: 30,  # 30-day automatic ban
    user_id: nil   # Mark as automatic
  )

  # Notify borrower
  BorrowerMailer.auto_ban_notification_email(borrower, ban)
    .deliver_later(queue: :critical)

  # Log for audit
  Rails.logger.info(
    "Auto-ban created for borrower #{borrower.id} " \
    "in department #{department.id} after #{warning_count} warnings"
  )

  ban
end

# Call this after creating a warning
after_commit :check_escalation, on: :create

private

def check_escalation
  return unless warned?
  self.class.check_warning_escalation(borrower, department)
end
```

### Phase 4: Scheduled Task

**Create rake task:**

```ruby
# lib/tasks/conducts.rake
namespace :bonanza do
  namespace :conducts do
    desc "Remove expired bans and notify borrowers"
    task cleanup: :environment do
      puts "Starting conduct cleanup..."

      result = Conduct.cleanup_expired

      puts "Removed #{result[:expired]} expired conducts"
      puts "Removed #{result[:stale]} stale automatic conducts"
      puts "Done!"
    end

    desc "Check for warning escalations (manual run)"
    task check_escalations: :environment do
      puts "Checking for borrowers with multiple warnings..."

      # Find borrowers with 2+ warnings but no ban in same department
      Borrower.joins(:conducts)
        .where(conducts: { kind: :warned })
        .group('borrowers.id', 'conducts.department_id')
        .having('COUNT(*) >= 2')
        .each do |borrower|
          borrower.conducts.select(:department_id).distinct.each do |conduct|
            Conduct.check_warning_escalation(borrower, conduct.department)
          end
        end

      puts "Done!"
    end
  end
end
```

**Add to clockwork scheduler:**

```ruby
# config/clock.rb
every(1.day, 'conduct_cleanup', at: '20:00', tz: 'Europe/Berlin') do
  puts "[#{Time.now}] Running: conduct_cleanup"
  Rake::Task['bonanza:conducts:cleanup'].invoke
  Rake::Task['bonanza:conducts:cleanup'].reenable
end
```

### Phase 5: Update Views

**Show expiration info in conduct display:**

```erb
<!-- app/views/conducts/_conduct.html.erb -->
<div class="conduct conduct-<%= conduct.kind %>">
  <div class="conduct-header">
    <span class="conduct-kind"><%= conduct.banned? ? 'Gesperrt' : 'Verwarnung' %></span>
    <span class="conduct-date"><%= l(conduct.created_at, format: :short) %></span>
  </div>

  <div class="conduct-reason"><%= conduct.reason %></div>

  <div class="conduct-duration">
    <% if conduct.permanent? %>
      <span class="badge badge-danger">Dauerhaft</span>
    <% elsif conduct.duration.present? %>
      <span class="badge badge-warning">
        Noch <%= conduct.days_remaining %> Tage
        (bis <%= l(conduct.expiration_date, format: :short) %>)
      </span>
    <% elsif conduct.automatic? %>
      <span class="badge badge-info">Automatisch (läuft nach 60 Tagen ab)</span>
    <% end %>
  </div>

  <% if conduct.automatic? %>
    <div class="conduct-note">
      <small>Automatisch erstellt</small>
    </div>
  <% else %>
    <div class="conduct-user">
      <small>Von: <%= conduct.user&.fullname || 'System' %></small>
    </div>
  <% end %>
</div>
```

### Phase 6: Email Templates

**Add ban_lifted email to BorrowerMailer:**

```ruby
# app/mailers/borrower_mailer.rb
def ban_lifted_notification_email(borrower, conduct_data)
  @borrower = borrower
  @conduct_data = conduct_data
  @department = Department.find(conduct_data['department_id'])

  mail(
    to: @borrower.email,
    subject: "Ihre Sperre in der #{@department.name} wurde aufgehoben"
  )
end

def auto_ban_notification_email(borrower, conduct)
  @borrower = borrower
  @conduct = conduct
  @department = conduct.department

  mail(
    to: @borrower.email,
    subject: "Automatische Sperre in der #{@department.name}"
  )
end
```

**Create email views:**

```erb
<!-- app/views/borrower_mailer/ban_lifted_notification_email.html.erb -->
<h1>Ihre Sperre wurde aufgehoben</h1>

<p>Guten Tag <%= @borrower.firstname %> <%= @borrower.lastname %>,</p>

<p>
  Ihre <%= @conduct_data['kind'] == 'banned' ? 'Sperre' : 'Verwarnung' %>
  in der <strong><%= @department.name %></strong> ist abgelaufen und wurde aufgehoben.
</p>

<p>Sie können ab sofort wieder Gegenstände ausleihen.</p>

<p>
  Bitte beachten Sie die Ausleihbedingungen, um zukünftige Sperren zu vermeiden.
</p>

<p>Mit freundlichen Grüßen,<br>
Das Team der <%= @department.name %></p>
```

```erb
<!-- app/views/borrower_mailer/auto_ban_notification_email.html.erb -->
<h1>Automatische Sperre</h1>

<p>Guten Tag <%= @borrower.firstname %> <%= @borrower.lastname %>,</p>

<p>
  Aufgrund von wiederholten Verwarnungen wurden Sie automatisch
  für <strong><%= @conduct.duration %> Tage</strong>
  in der <strong><%= @department.name %></strong> gesperrt.
</p>

<p><strong>Grund:</strong> <%= @conduct.reason %></p>

<p>
  Die Sperre läuft am <%= l(@conduct.expiration_date, format: :long) %> ab.
</p>

<p>
  Bei Fragen wenden Sie sich bitte an das Team der <%= @department.name %>.
</p>

<p>Mit freundlichen Grüßen,<br>
Das Team der <%= @department.name %></p>
```

## Validation Updates

**Fix duration validation:**

```ruby
# app/models/conduct.rb

validates :duration, numericality: {
  only_integer: true,
  greater_than: 0,  # Changed from allow_nil
  allow_nil: true,
  message: "muss eine positive Anzahl an Tagen sein."
}
```

## Deliverables

- [ ] `remove_expired_conducts` method implemented
- [ ] `remove_stale_automatic_conducts` method implemented
- [ ] Helper methods added (expired?, days_remaining, etc.)
- [ ] Warning escalation logic implemented
- [ ] Rake tasks created
- [ ] Clockwork scheduler updated
- [ ] Views updated to show expiration info
- [ ] Email templates created
- [ ] Tests written

## Files to Modify

| File | Change |
|------|--------|
| `app/models/conduct.rb` | Replace commented code, add methods |
| `lib/tasks/conducts.rake` | New file |
| `config/clock.rb` | Add cleanup task |
| `app/mailers/borrower_mailer.rb` | Add email methods |
| `app/views/borrower_mailer/` | Add email templates |
| `app/views/conducts/` | Update display views |

## Dependencies

- **Requires:** Background jobs plan (c1) for `.deliver_later`
- **Updates:** Email plan (c2) - adds BorrowerMailer methods
- **Integrates with:** Scheduler container from containerization plan
