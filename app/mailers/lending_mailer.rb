# ABOUTME: Mailer for lending lifecycle notifications sent to borrowers.
# ABOUTME: Covers confirmation, overdue, upcoming return, duration change, and department reopen events.

class LendingMailer < ApplicationMailer
  def confirmation_email(lending)
    @lending = lending
    @borrower = lending.borrower
    @user = lending.user
    @department = lending.department
    @due_date = lending.lent_at.to_date + lending.duration.days
    mail(
      to: @borrower.email,
      reply_to: "#{@user.fullname} <#{@user.email}>",
      subject: 'Ausleihbestaetigung'
    )
  end

  def overdue_notification_email(lending)
    @lending = lending
    @borrower = lending.borrower
    @user = lending.user
    @department = lending.department
    @due_date = lending.lent_at.to_date + lending.duration.days
    @days_overdue = (Date.today - @due_date).to_i
    mail(
      to: @borrower.email,
      reply_to: "#{@user.fullname} <#{@user.email}>",
      subject: 'Erinnerung: Leihfrist ueberschritten'
    )
  end

  def upcoming_return_notification_email(lending)
    @lending = lending
    @borrower = lending.borrower
    @user = lending.user
    @department = lending.department
    @due_date = lending.lent_at.to_date + lending.duration.days
    mail(
      to: @borrower.email,
      reply_to: "#{@user.fullname} <#{@user.email}>",
      subject: 'Erinnerung: Anstehende Rueckgabe'
    )
  end

  def upcoming_overdue_return_notification_email(lending)
    @lending = lending
    @borrower = lending.borrower
    @user = lending.user
    @department = lending.department
    @due_date = lending.lent_at.to_date + lending.duration.days
    mail(
      to: @borrower.email,
      reply_to: "#{@user.fullname} <#{@user.email}>",
      subject: 'Letzte Erinnerung: Rueckgabe morgen'
    )
  end

  def duration_change_notification_email(lending, old_duration)
    @lending = lending
    @borrower = lending.borrower
    @user = lending.user
    @department = lending.department
    @old_due_date = lending.lent_at.to_date + old_duration.days
    @new_due_date = lending.lent_at.to_date + lending.duration.days
    mail(
      to: @borrower.email,
      reply_to: "#{@user.fullname} <#{@user.email}>",
      subject: 'Aenderung Deiner Ausleihfrist'
    )
  end

  def department_staffed_again_notification_email(lending)
    @lending = lending
    @borrower = lending.borrower
    @department = lending.department
    @due_date = lending.lent_at.to_date + lending.duration.days
    mail(
      to: @borrower.email,
      subject: "Die #{@department.name} ist wieder geoeffnet"
    )
  end
end
