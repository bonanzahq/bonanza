# ABOUTME: Removes conduct records older than 5 years for GDPR compliance.
# ABOUTME: Runs weekly as a Solid Queue recurring task.

class GdprCleanupOldConductsJob < ApplicationJob
  queue_as :low

  def perform
    old_conducts = Conduct.where("created_at < ?", 5.years.ago)
    count = old_conducts.count
    old_conducts.destroy_all

    Rails.logger.info("GDPR: Deleted #{count} conducts older than 5 years")
  end
end
