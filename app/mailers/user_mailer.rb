# ABOUTME: Sends email notifications to staff users.
# ABOUTME: Includes daily returns digest and other staff-facing emails.

class UserMailer < ApplicationMailer
  def todays_returns_email(user, department, lendings)
    @user = user
    @department = department
    @lendings = lendings
    @line_items_count = lendings.sum { |l| l.line_items.where(returned_at: nil).count }
    mail(
      to: @user.email,
      subject: "Heutige Rueckgaben #{t(@department.genderize('in_the'))} #{@department.name}"
    )
  end
end
