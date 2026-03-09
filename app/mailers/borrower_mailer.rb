class BorrowerMailer < ApplicationMailer
  def confirm_email
    @borrower = params[:borrower]
    mail(to: @borrower.email, subject: 'Bestätige Deine Registrierung')
  end

  def ban_notification_email(conduct)
    @conduct = conduct
    @borrower = params[:borrower]
    options = { to: @borrower.email, subject: "Du wurdest gesperrt." }
    if @conduct.user
      options[:reply_to] = "#{@conduct.user.fullname} <#{@conduct.user.email}>"
    end
    mail(options)
  end

  def ban_lifted_notification_email(department_name:, department_genderize_in_the:, department_genderize_of_the:, user_fullname:, user_email:)
    @borrower = params[:borrower]
    @department_name = department_name
    @department_genderize_in_the = department_genderize_in_the
    @department_genderize_of_the = department_genderize_of_the
    @user_fullname = user_fullname
    @user_email = user_email
    mail(to: @borrower.email, reply_to: "#{@user_fullname} <#{@user_email}>", subject: "Deine Sperre wurde aufgehoben!")
  end

  def account_created_email(department_name:)
    @borrower = params[:borrower]
    @department_name = department_name
    mail(to: @borrower.email, subject: "Dein Konto bei Bonanza wurde erstellt")
  end

  def auto_ban_notification_email(conduct)
    @conduct = conduct
    @borrower = conduct.borrower
    @department = conduct.department
    mail(
      to: @borrower.email,
      subject: "Automatische Sperre #{t(@department.genderize('in_the'))} #{@department.name}"
    )
  end
end
