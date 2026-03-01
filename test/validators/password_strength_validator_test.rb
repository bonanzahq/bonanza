# ABOUTME: Tests for password strength validation using zxcvbn and unpwn.
# ABOUTME: Verifies weak, breached, and context-specific passwords are rejected.

require "test_helper"

class PasswordStrengthValidatorTest < ActiveSupport::TestCase
  # Helper to build a user with a given password
  def build_user_with_password(password, email: "test@example.com", firstname: "Test", lastname: "User")
    build(:user, password: password, password_confirmation: password, email: email, firstname: firstname, lastname: lastname)
  end

  test "strong password is accepted" do
    user = build_user_with_password("platypus-umbrella-cactus")
    assert user.valid?
  end

  test "weak common password is rejected" do
    # 12+ chars but very weak pattern - zxcvbn should score < 3
    user = build_user_with_password("aaaaaaaaaaaa")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "breached password is rejected" do
    # This is in every breach database
    user = build_user_with_password("password123456")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "password containing user email is penalized" do
    email = "testuser@example.com"
    # Use the email local part as password base - zxcvbn penalizes this
    user = build_user_with_password("testuser1234", email: email)
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "blank password is skipped" do
    # Simulates profile edit without password change
    user = create(:user)
    user.firstname = "Updated"
    user.password = nil
    user.password_confirmation = nil
    assert user.valid?
  end

  test "long password does not cause performance issues" do
    long_password = SecureRandom.urlsafe_base64(95) # ~127 chars, within Devise max
    user = build_user_with_password(long_password)
    # Should complete quickly (validator truncates to 100 chars for scoring)
    assert user.valid?
  end

  test "random passphrase with enough entropy is accepted" do
    # Simulates a 1Password-style random word passphrase
    user = build_user_with_password("purple-monkey-dishwasher-42")
    assert user.valid?
  end

  test "weak? class method returns true for weak passwords" do
    user = build(:user)
    assert PasswordStrengthValidator.weak?("aaaaaaaaaaaa", user)
  end

  test "weak? class method returns false for strong passwords" do
    user = build(:user)
    assert_not PasswordStrengthValidator.weak?("platypus-umbrella-cactus", user)
  end

  test "weak? class method returns false for blank passwords" do
    user = build(:user)
    assert_not PasswordStrengthValidator.weak?("", user)
    assert_not PasswordStrengthValidator.weak?(nil, user)
  end
end
