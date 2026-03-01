# ABOUTME: Integration tests for weak password nagware.
# ABOUTME: Verifies banner appears for weak passwords and disappears after password change.

require "test_helper"

class WeakPasswordWarningTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @strong_password = "platypus-umbrella-cactus"
    @weak_password = "aaaaaaaaaaaa"
  end

  test "banner shown after sign-in with weak password" do
    user = create_user_with_weak_password

    post user_session_path, params: { user: { email: user.email, password: @weak_password } }
    follow_redirect!

    assert_select ".alert-warning", text: /Dein Passwort ist unsicher/
  end

  test "no banner after sign-in with strong password" do
    user = create(:user, department: @department)

    post user_session_path, params: { user: { email: user.email, password: @strong_password } }
    follow_redirect!

    assert_select ".alert-warning", false
  end

  test "banner links to password change page" do
    user = create_user_with_weak_password

    post user_session_path, params: { user: { email: user.email, password: @weak_password } }
    follow_redirect!

    assert_select "a.alert-link[href=?]", edit_user_path(user)
  end

  test "banner persists across page navigations" do
    user = create_user_with_weak_password

    post user_session_path, params: { user: { email: user.email, password: @weak_password } }
    follow_redirect!
    assert_select ".alert-warning", text: /Dein Passwort ist unsicher/

    get edit_user_path(user)
    assert_select ".alert-warning", text: /Dein Passwort ist unsicher/
  end

  test "banner cleared after changing password to strong" do
    user = create_user_with_weak_password
    new_strong_password = "correct-horse-battery-staple"

    post user_session_path, params: { user: { email: user.email, password: @weak_password } }
    follow_redirect!
    assert_select ".alert-warning"

    patch user_path(user), params: {
      user: { password: new_strong_password, password_confirmation: new_strong_password }
    }
    follow_redirect!

    assert_select ".alert-warning", false
  end

  private

  def create_user_with_weak_password
    user = create(:user, department: @department)
    user.update_columns(encrypted_password: BCrypt::Password.create(@weak_password))
    user
  end
end
