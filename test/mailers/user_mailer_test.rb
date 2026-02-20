# ABOUTME: Tests for UserMailer delivery.
# ABOUTME: Verifies daily returns digest is addressed, formatted, and enqueued correctly.

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    @borrower = create(:borrower, :with_tos)
    @lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    create(:line_item, lending: @lending, item: item)
    @lendings = [ @lending ]
  end

  test "todays_returns_email is addressed to the user" do
    email = UserMailer.todays_returns_email(@user, @department, @lendings)
    assert_equal [ @user.email ], email.to
  end

  test "todays_returns_email has correct subject" do
    email = UserMailer.todays_returns_email(@user, @department, @lendings)
    assert_includes email.subject, "Heutige Rueckgaben"
    assert_includes email.subject, @department.name
  end

  test "todays_returns_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      UserMailer.todays_returns_email(@user, @department, @lendings).deliver_later
    end
  end

  test "todays_returns_email body contains borrower name" do
    email = UserMailer.todays_returns_email(@user, @department, @lendings)
    text_body = email.text_part.body.decoded
    assert_includes text_body, @borrower.fullname
  end
end
