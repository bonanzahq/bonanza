class BorrowerMailer < ApplicationMailer
  def confirm_email
    @borrower = params[:borrower]
    mail(to: @borrower.email, subject: 'Bestätige Deine Registrierung')
  end

  def ban_notification_email(conduct)
    @conduct = conduct
    @borrower = params[:borrower]
    mail(to: @borrower.email, :reply_to => "#{@conduct.user.fullname} <#{@conduct.user.email}>", subject: 'Du wurdest gesperrt.')
  end

  def ban_lifted_notification_email(conduct, user)
    @conduct = conduct
    @borrower = params[:borrower]
    @user = user
    mail(to: @borrower.email, :reply_to => "#{@user.fullname} <#{@user.email}>", subject: 'Deine Sperre wurde aufgehoben!')
  end

end
