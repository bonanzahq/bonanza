# ABOUTME: Tests for LendingMailer delivery.
# ABOUTME: Verifies recipient, subject, and reply-to for each mailer action.

require "test_helper"

class LendingMailerTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  setup do
    department = create(:department)
    user = create(:user, department: department)
    borrower = create(:borrower, :with_tos)
    @lending = create(:lending, :completed, user: user, department: department, borrower: borrower)
    parent_item = create(:parent_item, department: department)
    item = create(:item, parent_item: parent_item)
    create(:line_item, lending: @lending, item: item)
  end

  # confirmation_email

  test "confirmation_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      LendingMailer.confirmation_email(@lending).deliver_later
    end
  end

  test "confirmation_email is addressed to the borrower" do
    email = LendingMailer.confirmation_email(@lending)
    assert_equal [@lending.borrower.email], email.to
  end

  test "confirmation_email has correct subject" do
    email = LendingMailer.confirmation_email(@lending)
    assert_equal "Ausleihbestaetigung", email.subject
  end

  test "confirmation_email has reply_to set to lending user" do
    email = LendingMailer.confirmation_email(@lending)
    assert_includes email.reply_to, @lending.user.email
  end

  # overdue_notification_email

  test "overdue_notification_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      LendingMailer.overdue_notification_email(@lending).deliver_later
    end
  end

  test "overdue_notification_email is addressed to the borrower" do
    email = LendingMailer.overdue_notification_email(@lending)
    assert_equal [@lending.borrower.email], email.to
  end

  test "overdue_notification_email has correct subject" do
    email = LendingMailer.overdue_notification_email(@lending)
    assert_equal "Erinnerung: Leihfrist ueberschritten", email.subject
  end

  test "overdue_notification_email has reply_to set to lending user" do
    email = LendingMailer.overdue_notification_email(@lending)
    assert_includes email.reply_to, @lending.user.email
  end

  # upcoming_return_notification_email

  test "upcoming_return_notification_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      LendingMailer.upcoming_return_notification_email(@lending).deliver_later
    end
  end

  test "upcoming_return_notification_email is addressed to the borrower" do
    email = LendingMailer.upcoming_return_notification_email(@lending)
    assert_equal [@lending.borrower.email], email.to
  end

  test "upcoming_return_notification_email has correct subject" do
    email = LendingMailer.upcoming_return_notification_email(@lending)
    assert_equal "Erinnerung: Anstehende Rueckgabe", email.subject
  end

  test "upcoming_return_notification_email has reply_to set to lending user" do
    email = LendingMailer.upcoming_return_notification_email(@lending)
    assert_includes email.reply_to, @lending.user.email
  end

  # upcoming_overdue_return_notification_email

  test "upcoming_overdue_return_notification_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      LendingMailer.upcoming_overdue_return_notification_email(@lending).deliver_later
    end
  end

  test "upcoming_overdue_return_notification_email is addressed to the borrower" do
    email = LendingMailer.upcoming_overdue_return_notification_email(@lending)
    assert_equal [@lending.borrower.email], email.to
  end

  test "upcoming_overdue_return_notification_email has correct subject" do
    email = LendingMailer.upcoming_overdue_return_notification_email(@lending)
    assert_equal "Letzte Erinnerung: Rueckgabe morgen", email.subject
  end

  test "upcoming_overdue_return_notification_email has reply_to set to lending user" do
    email = LendingMailer.upcoming_overdue_return_notification_email(@lending)
    assert_includes email.reply_to, @lending.user.email
  end

  # duration_change_notification_email

  test "duration_change_notification_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      LendingMailer.duration_change_notification_email(@lending, 7).deliver_later
    end
  end

  test "duration_change_notification_email is addressed to the borrower" do
    email = LendingMailer.duration_change_notification_email(@lending, 7)
    assert_equal [@lending.borrower.email], email.to
  end

  test "duration_change_notification_email has correct subject" do
    email = LendingMailer.duration_change_notification_email(@lending, 7)
    assert_equal "Aenderung Deiner Ausleihfrist", email.subject
  end

  test "duration_change_notification_email has reply_to set to lending user" do
    email = LendingMailer.duration_change_notification_email(@lending, 7)
    assert_includes email.reply_to, @lending.user.email
  end

  # department_staffed_again_notification_email

  test "department_staffed_again_notification_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      LendingMailer.department_staffed_again_notification_email(@lending).deliver_later
    end
  end

  test "department_staffed_again_notification_email is addressed to the borrower" do
    email = LendingMailer.department_staffed_again_notification_email(@lending)
    assert_equal [@lending.borrower.email], email.to
  end

  test "department_staffed_again_notification_email has correct subject" do
    email = LendingMailer.department_staffed_again_notification_email(@lending)
    assert_equal "Die #{@lending.department.name} ist wieder geoeffnet", email.subject
  end
end
