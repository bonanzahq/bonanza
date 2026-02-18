# ABOUTME: Anonymizes borrower records that have been inactive for 24+ months.
# ABOUTME: Runs weekly as a Solid Queue recurring task for GDPR compliance.

class GdprAnonymizeInactiveBorrowersJob < ApplicationJob
  queue_as :low

  def perform
    inactive = Borrower.left_joins(:lendings)
      .where(lendings: { id: nil })
      .where("borrowers.updated_at < ?", 24.months.ago)
      .where.not(borrower_type: :deleted)

    count = 0
    inactive.find_each do |borrower|
      borrower.anonymize!
      count += 1
    end

    Rails.logger.info("GDPR: Anonymized #{count} inactive borrowers")
  end
end
