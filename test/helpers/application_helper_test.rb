# ABOUTME: Tests for ApplicationHelper methods.
# ABOUTME: Verifies nil-safe user display name rendering.

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "user_display_name returns fullname when user exists" do
    user = build(:user, firstname: "Max", lastname: "Mustermann")
    assert_equal "Max Mustermann", user_display_name(user)
  end

  test "user_display_name returns Gelöschtes Konto when user is nil" do
    assert_equal "Gelöschtes Konto", user_display_name(nil)
  end
end
