# Preview all emails at http://localhost:3000/rails/mailers/borrower_mailer
class BorrowerMailerPreview < ActionMailer::Preview
	def confirm_email
    BorrowerMailer.with(borrower: Borrower.first).confirm_email
  end

  def ban_notification_email
    @conduct = Conduct.first
    @conduct = Conduct.find(4)
    # @conduct = Conduct.find(5)
    BorrowerMailer.with(borrower: Borrower.first).ban_notification_email(@conduct)
  end

  def ban_lifted_notification_email
    @conduct = Conduct.first
    # @conduct = Conduct.find(4)
    # @conduct = Conduct.find(5)
    BorrowerMailer.with(borrower: Borrower.first).ban_lifted_notification_email(@conduct, User.first)
  end
end
