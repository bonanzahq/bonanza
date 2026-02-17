# ABOUTME: Integration tests for UsersController.
# ABOUTME: Covers auth security: registration route disabled, password change restrictions.

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @admin = create(:user, :admin, department: @department)
    @leader = create(:user, :leader, department: @department)
    @member = create(:user, department: @department)
  end

  # -- Bug 1: Devise registration route should not exist --

  test "devise sign_up route does not exist" do
    assert_raises(ActionController::RoutingError) do
      get "/register/register"
    end
  end

  test "devise registration create route does not exist" do
    assert_raises(ActionController::RoutingError) do
      post "/register"
    end
  end

  # -- Bug 2: Password change restricted to self-edit --

  test "user can change their own password" do
    sign_in @member
    new_password = "new-platypus-umbrella-cactus"
    patch user_path(@member), params: {
      user: { password: new_password, password_confirmation: new_password }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert @member.reload.valid_password?(new_password), "Password should have been updated"
  end

  test "admin cannot set another user's password" do
    sign_in @admin
    original_password = @member.encrypted_password
    patch user_path(@member), params: {
      user: { password: "hacked-password-12345", password_confirmation: "hacked-password-12345" }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert_equal original_password, @member.reload.encrypted_password,
      "Password should not have been changed by admin"
  end

  test "leader cannot set another user's password in same department" do
    sign_in @leader
    original_password = @member.encrypted_password
    patch user_path(@member), params: {
      user: { password: "hacked-password-12345", password_confirmation: "hacked-password-12345" }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert_equal original_password, @member.reload.encrypted_password,
      "Password should not have been changed by leader"
  end

  test "admin can trigger password reset for another user" do
    sign_in @admin
    post send_password_reset_user_path(@member)
    assert_redirected_to edit_user_path(@member)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "leader can trigger password reset for user in same department" do
    sign_in @leader
    post send_password_reset_user_path(@member)
    assert_redirected_to edit_user_path(@member)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "member cannot trigger password reset for another user" do
    sign_in @member
    post send_password_reset_user_path(@leader)
    assert_redirected_to root_path
  end
end
