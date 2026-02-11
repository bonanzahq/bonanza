# GDPR & Data Retention Plan

## Problem Statement

README TODO mentions "Auto-delete inactive borrowers after X months" but this isn't implemented. GDPR requires:

1. **Data minimization** - Don't keep data longer than necessary
2. **Right to erasure** - Users can request deletion
3. **Data portability** - Users can export their data

## Current State

- Borrowers are soft-deleted (`borrower_type: :deleted`) but data remains
- No automatic cleanup of old records
- No data export functionality
- Legal texts exist but no versioning strategy

## Retention Policy

| Data Type | Retention Period | Action | Rationale |
|-----------|------------------|--------|-----------|
| Inactive borrowers (no lendings) | 24 months | Delete completely | No business need |
| Borrowers with lending history | 7 years | Anonymize | German accounting law (HGB §257) |
| Lending records | 7 years | Keep then archive | German accounting law |
| Conducts | 5 years after expiry | Delete | Proportionality |
| Item histories | 7 years | Keep | Asset tracking |
| User accounts (staff) | Until offboarded + 1 year | Anonymize | Employment records |

## Implementation Plan

### Phase 1: Anonymization Logic

**Add anonymization method to Borrower:**

```ruby
# app/models/borrower.rb

def anonymize!
  transaction do
    # Clear personal data
    update!(
      firstname: 'Gelöscht',
      lastname: 'Nutzer',
      email: "deleted-#{id}-#{SecureRandom.hex(4)}@anonymized.local",
      phone: '000000',
      student_id: nil,
      email_token: nil,
      borrower_type: :deleted
    )

    # Clear any associated data
    # (conducts are kept for department records but borrower is anonymized)

    Rails.logger.info("Anonymized borrower #{id}")
  end
end

def anonymized?
  email&.end_with?('@anonymized.local')
end
```

**Add anonymization to User (for offboarded staff):**

```ruby
# app/models/user.rb

def anonymize!
  transaction do
    update!(
      firstname: 'Ehemaliger',
      lastname: 'Mitarbeiter',
      email: "former-#{id}-#{SecureRandom.hex(4)}@anonymized.local"
    )

    # Remove from all departments
    department_memberships.destroy_all

    Rails.logger.info("Anonymized user #{id}")
  end
end
```

### Phase 2: Cleanup Tasks

**Create GDPR rake tasks:**

```ruby
# lib/tasks/gdpr.rake
namespace :bonanza do
  namespace :gdpr do
    desc "Clean up old borrower data per retention policy"
    task cleanup: :environment do
      puts "Starting GDPR cleanup..."

      deleted_inactive = cleanup_inactive_borrowers
      anonymized_old = anonymize_old_borrowers
      deleted_conducts = cleanup_old_conducts

      puts "Results:"
      puts "  - Deleted #{deleted_inactive} inactive borrowers"
      puts "  - Anonymized #{anonymized_old} borrowers with old history"
      puts "  - Deleted #{deleted_conducts} old conducts"
      puts "Done!"
    end

    desc "Generate data retention report"
    task report: :environment do
      puts "=== Data Retention Report ==="
      puts "Generated: #{Time.current}"
      puts ""

      puts "Borrowers:"
      puts "  Total: #{Borrower.count}"
      puts "  Active (with lendings): #{Borrower.joins(:lendings).distinct.count}"
      puts "  Inactive (no lendings): #{Borrower.left_joins(:lendings).where(lendings: { id: nil }).count}"
      puts "  Anonymized: #{Borrower.where(borrower_type: :deleted).count}"
      puts "  Eligible for deletion (inactive 24+ months): #{inactive_borrowers_for_deletion.count}"
      puts "  Eligible for anonymization (7+ years): #{borrowers_for_anonymization.count}"
      puts ""

      puts "Lendings:"
      puts "  Total: #{Lending.count}"
      puts "  Active: #{Lending.where(returned_at: nil).count}"
      puts "  Older than 7 years: #{Lending.where('created_at < ?', 7.years.ago).count}"
      puts ""

      puts "Conducts:"
      puts "  Total: #{Conduct.count}"
      puts "  Expired (5+ years): #{old_conducts.count}"
    end

    private

    def cleanup_inactive_borrowers
      # Delete borrowers with no lendings who haven't been active in 24 months
      inactive = inactive_borrowers_for_deletion
      count = inactive.count
      inactive.destroy_all
      count
    end

    def inactive_borrowers_for_deletion
      Borrower.left_joins(:lendings)
        .where(lendings: { id: nil })
        .where('borrowers.updated_at < ?', 24.months.ago)
        .where.not(borrower_type: :deleted)
    end

    def anonymize_old_borrowers
      # Anonymize borrowers whose last lending was 7+ years ago
      old_borrowers = borrowers_for_anonymization
      count = 0

      old_borrowers.find_each do |borrower|
        borrower.anonymize!
        count += 1
      end

      count
    end

    def borrowers_for_anonymization
      Borrower.joins(:lendings)
        .where.not(borrower_type: :deleted)
        .group('borrowers.id')
        .having('MAX(lendings.created_at) < ?', 7.years.ago)
    end

    def cleanup_old_conducts
      # Delete conducts that expired 5+ years ago
      old = old_conducts
      count = old.count
      old.destroy_all
      count
    end

    def old_conducts
      # Permanent conducts older than 5 years
      permanent_old = Conduct.where(permanent: true)
        .where('created_at < ?', 5.years.ago)

      # Non-permanent conducts that expired 5+ years ago
      expired_old = Conduct.where(permanent: false)
        .where.not(duration: nil)
        .where('created_at + (duration * INTERVAL \'1 day\') < ?', 5.years.ago)

      Conduct.where(id: permanent_old.select(:id))
        .or(Conduct.where(id: expired_old.select(:id)))
    end
  end
end
```

### Phase 3: Data Export

**Add data export method:**

```ruby
# app/models/borrower.rb

def export_personal_data
  {
    personal_information: {
      firstname: firstname,
      lastname: lastname,
      email: email,
      phone: phone,
      student_id: student_id,
      type: borrower_type,
      registered_at: created_at.iso8601,
      tos_accepted_at: tos_accepted_at&.iso8601
    },
    lendings: lendings.map do |lending|
      {
        date: lending.lent_at&.iso8601,
        returned_at: lending.returned_at&.iso8601,
        duration_days: lending.duration,
        department: lending.department.name,
        items: lending.line_items.map do |li|
          {
            name: li.item.parent_item.name,
            uid: li.item.uid,
            returned_at: li.returned_at&.iso8601
          }
        end
      }
    end,
    conducts: conducts.map do |conduct|
      {
        type: conduct.kind,
        reason: conduct.reason,
        created_at: conduct.created_at.iso8601,
        department: conduct.department.name,
        duration_days: conduct.duration,
        permanent: conduct.permanent
      }
    end,
    export_generated_at: Time.current.iso8601
  }
end

def export_personal_data_json
  export_personal_data.to_json
end
```

**Add controller action for data export:**

```ruby
# app/controllers/borrowers_controller.rb

def export_data
  @borrower = Borrower.find(params[:id])
  authorize! :read, @borrower

  respond_to do |format|
    format.json do
      send_data @borrower.export_personal_data_json,
        filename: "borrower-data-#{@borrower.id}-#{Date.today}.json",
        type: 'application/json'
    end
  end
end
```

### Phase 4: Scheduled Cleanup

**Add to clockwork scheduler:**

```ruby
# config/clock.rb

# Run GDPR cleanup weekly on Sunday at 3 AM
every(1.week, 'gdpr_cleanup', at: 'Sunday 03:00', tz: 'Europe/Berlin') do
  puts "[#{Time.now}] Running: gdpr_cleanup"
  Rake::Task['bonanza:gdpr:cleanup'].invoke
  Rake::Task['bonanza:gdpr:cleanup'].reenable
end

# Generate monthly report
every(1.month, 'gdpr_report', at: 'First 09:00', tz: 'Europe/Berlin') do
  puts "[#{Time.now}] Running: gdpr_report"
  Rake::Task['bonanza:gdpr:report'].invoke
  Rake::Task['bonanza:gdpr:report'].reenable
end
```

### Phase 5: Manual Deletion Request

**Add deletion request handling:**

```ruby
# app/models/borrower.rb

def request_deletion!
  # Check if borrower has active lendings
  if lendings.where(returned_at: nil).exists?
    raise ActiveRecord::RecordInvalid, "Kann nicht gelöscht werden: Offene Ausleihen vorhanden"
  end

  # Check if within retention period
  if lendings.where('created_at > ?', 7.years.ago).exists?
    # Has recent history - anonymize instead of delete
    anonymize!
    :anonymized
  else
    # No recent history - can fully delete
    destroy!
    :deleted
  end
end
```

```ruby
# app/controllers/borrowers_controller.rb

def request_deletion
  @borrower = Borrower.find(params[:id])
  authorize! :destroy, @borrower

  result = @borrower.request_deletion!

  case result
  when :anonymized
    flash[:notice] = "Die personenbezogenen Daten wurden anonymisiert."
  when :deleted
    flash[:notice] = "Der Datensatz wurde vollständig gelöscht."
  end

  redirect_to borrowers_path
rescue ActiveRecord::RecordInvalid => e
  flash[:alert] = e.message
  redirect_to @borrower
end
```

### Phase 6: Audit Logging

**Log all GDPR-relevant actions:**

```ruby
# app/models/concerns/gdpr_auditable.rb
module GdprAuditable
  extend ActiveSupport::Concern

  included do
    after_commit :log_gdpr_action, on: [:create, :update, :destroy]
  end

  private

  def log_gdpr_action
    action = destroyed? ? 'deleted' : (previously_new_record? ? 'created' : 'updated')

    Rails.logger.info({
      gdpr_audit: true,
      action: action,
      model: self.class.name,
      record_id: id,
      user_id: User.current_user&.id,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
```

```ruby
# app/models/borrower.rb
class Borrower < ApplicationRecord
  include GdprAuditable
  # ...
end
```

## Routes

```ruby
# config/routes.rb
resources :borrowers do
  member do
    get :export_data
    post :request_deletion
  end
end
```

## Deliverables

- [ ] Anonymization methods for Borrower and User
- [ ] GDPR cleanup rake tasks
- [ ] Data export functionality
- [ ] Scheduled cleanup via clockwork
- [ ] Manual deletion request handling
- [ ] Audit logging for GDPR actions
- [ ] Routes for export and deletion
- [ ] Documentation of retention policy

## Files to Create/Modify

| File | Change |
|------|--------|
| `app/models/borrower.rb` | Add anonymize!, export_personal_data, request_deletion! |
| `app/models/user.rb` | Add anonymize! |
| `app/models/concerns/gdpr_auditable.rb` | New file |
| `lib/tasks/gdpr.rake` | New file |
| `config/clock.rb` | Add weekly cleanup task |
| `app/controllers/borrowers_controller.rb` | Add export_data, request_deletion |
| `config/routes.rb` | Add member routes |


## Legal Notes

- **Consult legal counsel** before implementing retention periods
- Retention periods in this plan are based on German HGB requirements
- University may have additional requirements
- Consider documenting consent at registration time
- GDPR Article 17 exceptions may apply (legal obligations, public interest)

## Testing

```ruby
# test/models/borrower_test.rb
class BorrowerGdprTest < ActiveSupport::TestCase
  test "anonymize clears personal data" do
    borrower = create(:borrower, firstname: 'Max', email: 'max@example.com')
    borrower.anonymize!

    assert_equal 'Gelöscht', borrower.firstname
    assert borrower.email.end_with?('@anonymized.local')
    assert borrower.deleted?
  end

  test "export includes all personal data" do
    borrower = create(:borrower, :with_lendings)
    data = borrower.export_personal_data

    assert data[:personal_information].present?
    assert data[:lendings].present?
    assert data[:export_generated_at].present?
  end

  test "cannot delete borrower with active lending" do
    borrower = create(:borrower)
    create(:lending, borrower: borrower, returned_at: nil)

    assert_raises(ActiveRecord::RecordInvalid) do
      borrower.request_deletion!
    end
  end
end
```
