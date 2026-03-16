# ABOUTME: Tests for BorrowerMailer delivery.
# ABOUTME: Verifies that mailer actions enqueue jobs correctly with deliver_later.

require "test_helper"

class BorrowerMailerTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  setup do
    @borrower = create(:borrower)
    @borrower.update_column(:email_token, "abc123token")
    @department = create(:department)
  end

  # confirm_email

  test "confirm_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      BorrowerMailer.with(borrower: @borrower).confirm_email.deliver_later
    end
  end

  test "confirm_email is addressed to the borrower" do
    email = BorrowerMailer.with(borrower: @borrower).confirm_email
    assert_equal [@borrower.email], email.to
  end

  test "confirm_email has both HTML and text parts" do
    email = BorrowerMailer.with(borrower: @borrower).confirm_email
    assert_not_nil email.html_part
    assert_not_nil email.text_part
  end

  # ban_notification_email

  test "ban_notification_email is addressed to the borrower" do
    conduct = build_banned_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_notification_email(conduct)
    assert_equal [conduct.borrower.email], email.to
  end

  test "ban_notification_email has correct subject" do
    conduct = build_banned_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_notification_email(conduct)
    assert_equal "Du wurdest gesperrt.", email.subject
  end

  test "ban_notification_email has correct reply_to" do
    conduct = build_banned_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_notification_email(conduct)
    assert_equal [conduct.user.email], email.reply_to
  end

  test "ban_notification_email has both HTML and text parts" do
    conduct = build_banned_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_notification_email(conduct)
    assert_not_nil email.html_part
    assert_not_nil email.text_part
  end

  test "ban_notification_email renders without error when conduct user is nil" do
    conduct = build_banned_conduct
    conduct.update_column(:user_id, nil)
    conduct.reload
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_notification_email(conduct)
    assert_equal [conduct.borrower.email], email.to
    assert_nil email.reply_to
    assert_includes email.html_part.body.to_s, "Gelöschtes Konto"
    assert_includes email.text_part.body.to_s, "Gelöschtes Konto"
  end

  # ban_lifted_notification_email

  test "ban_lifted_notification_email is addressed to the borrower" do
    conduct, user = build_ban_lifted_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_lifted_notification_email(**ban_lifted_primitives(conduct, user))
    assert_equal [conduct.borrower.email], email.to
  end

  test "ban_lifted_notification_email has correct subject" do
    conduct, user = build_ban_lifted_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_lifted_notification_email(**ban_lifted_primitives(conduct, user))
    assert_equal "Deine Sperre wurde aufgehoben!", email.subject
  end

  test "ban_lifted_notification_email has correct reply_to" do
    conduct, user = build_ban_lifted_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_lifted_notification_email(**ban_lifted_primitives(conduct, user))
    assert_equal [user.email], email.reply_to
  end

  test "ban_lifted_notification_email has both HTML and text parts" do
    conduct, user = build_ban_lifted_conduct
    email = BorrowerMailer.with(borrower: conduct.borrower).ban_lifted_notification_email(**ban_lifted_primitives(conduct, user))
    assert_not_nil email.html_part
    assert_not_nil email.text_part
  end

  test "ban_lifted_notification_email renders correctly after conduct is destroyed" do
    conduct, user = build_ban_lifted_conduct
    primitives = ban_lifted_primitives(conduct, user)
    borrower = conduct.borrower
    conduct.destroy

    email = BorrowerMailer.with(borrower: borrower).ban_lifted_notification_email(**primitives)
    assert_equal [borrower.email], email.to
    assert_equal "Deine Sperre wurde aufgehoben!", email.subject
    assert_not_nil email.html_part
  end

  # auto_ban_notification_email

  test "auto_ban_notification_email is addressed to the borrower" do
    conduct = build_banned_conduct
    email = BorrowerMailer.auto_ban_notification_email(conduct)
    assert_equal [conduct.borrower.email], email.to
  end

  test "auto_ban_notification_email subject contains department name" do
    conduct = build_banned_conduct
    email = BorrowerMailer.auto_ban_notification_email(conduct)
    assert_includes email.subject, conduct.department.name
  end

  test "auto_ban_notification_email subject starts with Automatische Sperre" do
    conduct = build_banned_conduct
    email = BorrowerMailer.auto_ban_notification_email(conduct)
    assert_match(/\AAutomatische Sperre/, email.subject)
  end

  test "auto_ban_notification_email has both HTML and text parts" do
    conduct = build_banned_conduct
    email = BorrowerMailer.auto_ban_notification_email(conduct)
    assert_not_nil email.html_part
    assert_not_nil email.text_part
  end

  # account_created_email

  test "account_created_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      BorrowerMailer.with(borrower: @borrower).account_created_email(department_name: @department.name).deliver_later
    end
  end

  test "account_created_email is addressed to the borrower" do
    email = BorrowerMailer.with(borrower: @borrower).account_created_email(department_name: @department.name)
    assert_equal [@borrower.email], email.to
  end

  test "account_created_email has correct subject" do
    email = BorrowerMailer.with(borrower: @borrower).account_created_email(department_name: @department.name)
    assert_equal "Dein Konto bei Bonanza wurde erstellt", email.subject
  end

  test "account_created_email has both HTML and text parts" do
    email = BorrowerMailer.with(borrower: @borrower).account_created_email(department_name: @department.name)
    assert_not_nil email.html_part
    assert_not_nil email.text_part
  end

  test "account_created_email body contains department name" do
    email = BorrowerMailer.with(borrower: @borrower).account_created_email(department_name: @department.name)
    assert_includes email.text_part.body.to_s, @department.name
    assert_includes email.html_part.body.to_s, @department.name
  end

  test "account_created_email body contains borrower firstname" do
    email = BorrowerMailer.with(borrower: @borrower).account_created_email(department_name: @department.name)
    assert_includes email.text_part.body.to_s, @borrower.firstname
    assert_includes email.html_part.body.to_s, @borrower.firstname
  end

  private

  def build_banned_conduct
    department = create(:department)
    user = create(:user, department: department)
    borrower = create(:borrower)
    create(:conduct, borrower: borrower, department: department, user: user, kind: :banned, duration: 30, permanent: false)
  end

  def build_ban_lifted_conduct
    department = create(:department)
    user = create(:user, department: department)
    borrower = create(:borrower)
    conduct = create(:conduct, borrower: borrower, department: department, user: user, kind: :banned, duration: 30, permanent: false)
    [ conduct, user ]
  end

  def ban_lifted_primitives(conduct, user)
    {
      department_name: conduct.department.name,
      department_genderize_in_the: conduct.department.genderize("in_the"),
      department_genderize_of_the: conduct.department.genderize("of_the"),
      user_fullname: user.fullname,
      user_email: user.email
    }
  end
end
