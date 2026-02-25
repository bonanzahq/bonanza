# ABOUTME: Tests for email address change confirmation behavior on the User model.
# ABOUTME: Verifies that Devise :confirmable reconfirmation works as expected.

require "test_helper"

class UserEmailConfirmationTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    ActionMailer::Base.deliveries.clear
  end

  test "existing factory-created user has confirmed_at set" do
    assert_not_nil @user.confirmed_at, "Factory user should have confirmed_at set"
  end

  test "changing email stores new address in unconfirmed_email" do
    old_email = @user.email
    new_email = "new-address@example.com"

    @user.update(email: new_email)

    assert_equal old_email, @user.reload.email,
      "Original email should remain active until confirmed"
    assert_equal new_email, @user.unconfirmed_email,
      "New email should be stored in unconfirmed_email"
  end

  test "original email remains active until confirmation" do
    @user.update(email: "pending@example.com")

    assert @user.reload.valid_password?("platypus-umbrella-cactus"),
      "User should still have a valid password"
    assert_equal @user.email, @user.reload.email,
      "Original email should still be on record"
  end

  test "confirmation email is sent on email change" do
    @user.update(email: "needs-confirmation@example.com")

    assert_equal 1, ActionMailer::Base.deliveries.size,
      "One email should be sent when email changes"
    assert_match "needs-confirmation@example.com", ActionMailer::Base.deliveries.last.to.to_s,
      "Confirmation email should be sent to the new address"
  end

  test "confirming email completes the change" do
    new_email = "confirmed-new@example.com"
    @user.update(email: new_email)

    @user.confirm

    assert_equal new_email, @user.reload.email,
      "Email should be updated after confirmation"
    assert_nil @user.unconfirmed_email,
      "unconfirmed_email should be cleared after confirmation"
  end

  test "non-email updates do not trigger confirmation" do
    @user.update(firstname: "Neuer")

    assert_nil @user.reload.unconfirmed_email,
      "No unconfirmed_email should be set for non-email updates"
    assert_equal 0, ActionMailer::Base.deliveries.size,
      "No confirmation email should be sent for non-email updates"
  end
end
