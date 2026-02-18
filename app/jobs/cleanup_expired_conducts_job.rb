# ABOUTME: Job that removes expired conduct records and notifies affected borrowers.
# ABOUTME: Sends ban_lifted_notification_email for each removed conduct.

class CleanupExpiredConductsJob < ApplicationJob
  queue_as :low

  def perform
    removed = Conduct.remove_expired
    removed.each do |conduct|
      next unless conduct.borrower.present?
      BorrowerMailer.with(borrower: conduct.borrower)
        .ban_lifted_notification_email(conduct, nil)
        .deliver_later(queue: :default)
    end
    Rails.logger.info("Cleaned up #{removed.size} expired conducts")
  end
end
