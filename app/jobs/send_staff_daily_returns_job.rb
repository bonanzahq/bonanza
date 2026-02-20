# ABOUTME: Job that sends daily return digest emails to non-guest staff.
# ABOUTME: Iterates departments and mails staff about items due back today.

class SendStaffDailyReturnsJob < ApplicationJob
  queue_as :low

  def perform
    Department.find_each do |department|
      lendings = department.lendings
        .where(returned_at: nil)
        .where.not(lent_at: nil, duration: nil)
        .where("DATE(lent_at + (duration * INTERVAL '1 day')) = ?", Date.current)

      next if lendings.empty?

      department.users.each do |user|
        next if user.guest? || user.is_guest_everywhere?
        UserMailer.todays_returns_email(user, department, lendings).deliver_later(queue: :low)
      end
    end
  end
end
