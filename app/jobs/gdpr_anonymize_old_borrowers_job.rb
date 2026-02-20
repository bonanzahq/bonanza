# ABOUTME: Anonymizes borrower records whose lending history exceeds the 7-year retention period.
# ABOUTME: Runs weekly as a Solid Queue recurring task for GDPR compliance.

class GdprAnonymizeOldBorrowersJob < ApplicationJob
  queue_as :low

  def perform
    old_borrowers = Borrower.joins(:lendings)
      .where.not(borrower_type: :deleted)
      .group("borrowers.id")
      .having("MAX(lendings.created_at) < ?", 7.years.ago)

    count = 0
    old_borrowers.find_each do |borrower|
      borrower.anonymize!
      count += 1
    end

    Rails.logger.info("GDPR: Anonymized #{count} borrowers past retention period")
  end
end
