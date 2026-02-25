# ABOUTME: Integration tests for email change confirmation flow in UsersController.
# ABOUTME: Verifies that changing a user's email triggers the reconfirmation workflow.

require "test_helper"

class UsersEmailChangeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @admin = create(:user, :admin, department: @department)
    @member = create(:user, department: @department)
    ActionMailer::Base.deliveries.clear
  end

  test "admin changing another user's email triggers reconfirmation" do
    sign_in @admin
    new_email = "admin-changed@example.com"

    patch user_path(@member), params: {
      user: { email: new_email }
    }

    assert_not_equal new_email, @member.reload.email,
      "Email should not immediately change"
    assert_equal new_email, @member.reload.unconfirmed_email,
      "New email should be stored as unconfirmed"
  end

  test "user changing own email triggers reconfirmation" do
    sign_in @member
    new_email = "self-changed@example.com"

    patch user_path(@member), params: {
      user: { email: new_email }
    }

    assert_not_equal new_email, @member.reload.email,
      "Email should not immediately change"
    assert_equal new_email, @member.reload.unconfirmed_email,
      "New email should be stored as unconfirmed"
  end

  test "flash message shown after email change mentions confirmation" do
    sign_in @admin
    new_email = "flash-test@example.com"

    patch user_path(@member), params: {
      user: { email: new_email }
    }

    assert_redirected_to verwaltung_verleihende_path
    assert_match "bestätige", flash[:notice],
      "Flash should mention confirmation"
  end
end
