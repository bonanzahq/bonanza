# ABOUTME: Job that sends overdue lending notifications to borrowers.
# ABOUTME: Delegates to Lending.notify_borrowers_of_overdue_lending.

class SendOverdueNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    Lending.notify_borrowers_of_overdue_lending
  end
end
