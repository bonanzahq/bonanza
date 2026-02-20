# ABOUTME: Job that sends return reminders for lendings due tomorrow.
# ABOUTME: Delegates to Lending.notify_borrowers_of_upcoming_return.

class SendUpcomingReturnRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Lending.notify_borrowers_of_upcoming_return
  end
end
