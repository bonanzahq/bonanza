# ABOUTME: Rake task to anonymize PII in staging databases.
# ABOUTME: Replaces borrower, conduct, lending, and item_history data with Faker values.

def anonymize_borrowers
  count = 0
  Borrower.where.not(borrower_type: :deleted).find_each do |borrower|
    next if borrower.anonymized?

    Faker::Config.random = Random.new(borrower.id)

    attrs = {
      firstname: Faker::Name.first_name,
      lastname: Faker::Name.last_name,
      email: "anon-#{borrower.id}@staging.local",
      phone: Faker::PhoneNumber.phone_number,
      email_token: nil
    }

    if borrower.student_id.present?
      attrs[:student_id] = borrower.id.to_s.rjust(8, "0")
    end

    borrower.update_columns(attrs)
    count += 1
  end
  puts "  Anonymized #{count} borrowers."
end

def anonymize_conducts
  count = 0
  Conduct.find_each do |conduct|
    Faker::Config.random = Random.new(conduct.id)
    conduct.update_columns(reason: Faker::Lorem.sentence)
    count += 1
  end
  puts "  Anonymized #{count} conduct records."
end

def anonymize_lending_notes
  count = 0
  Lending.where.not(note: nil).find_each do |lending|
    Faker::Config.random = Random.new(lending.id)
    lending.update_columns(note: Faker::Lorem.sentence)
    count += 1
  end
  puts "  Anonymized #{count} lending notes."
end

def anonymize_item_history_notes
  count = 0
  ItemHistory.where.not(note: nil).find_each do |history|
    Faker::Config.random = Random.new(history.id)
    history.update_columns(note: Faker::Lorem.sentence)
    count += 1
  end
  puts "  Anonymized #{count} item history notes."
end

def delete_gdpr_audit_logs
  count = GdprAuditLog.delete_all
  puts "  Deleted #{count} GDPR audit logs."
end

namespace :staging do
  desc "Anonymize all PII in the database for staging use"
  task anonymize: :environment do
    unless ENV["ALLOW_ANONYMIZE"] == "yes"
      abort "REFUSED: set ALLOW_ANONYMIZE=yes to run this task (current value: #{ENV.fetch("ALLOW_ANONYMIZE", "<not set>")})"
    end

    require "faker"

    puts "Anonymizing staging data..."

    ActiveRecord::Base.transaction do
      anonymize_borrowers
      anonymize_conducts
      anonymize_lending_notes
      anonymize_item_history_notes
      delete_gdpr_audit_logs
    end

    begin
      Borrower.reindex
      puts "Anonymization complete. Borrower index rebuilt."
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
      puts "Anonymization complete. WARNING: Could not reindex borrowers: #{e.message}"
    end
  end
end
