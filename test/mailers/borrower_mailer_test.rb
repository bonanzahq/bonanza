# ABOUTME: Tests for BorrowerMailer delivery.
# ABOUTME: Verifies that mailer actions enqueue jobs correctly with deliver_later.

require "test_helper"

class BorrowerMailerTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  setup do
    @borrower = create(:borrower)
    @borrower.update_column(:email_token, "abc123token")
  end

  test "confirm_email is enqueued with deliver_later" do
    assert_enqueued_emails(1) do
      BorrowerMailer.with(borrower: @borrower).confirm_email.deliver_later
    end
  end

  test "confirm_email is addressed to the borrower" do
    email = BorrowerMailer.with(borrower: @borrower).confirm_email
    assert_equal [@borrower.email], email.to
  end
end
