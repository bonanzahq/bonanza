# ABOUTME: Job that notifies borrowers of overdue lendings in recently reopened departments.
# ABOUTME: Delegates to Lending.notify_borrowers_of_staffed_department.

class SendStaffedDepartmentNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    Lending.notify_borrowers_of_staffed_department
  end
end
