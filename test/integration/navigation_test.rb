# ABOUTME: Tests for navigation elements in the layout.
# ABOUTME: Verifies Verwaltung link appears in user dropdown for authorized users.

require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
  end

  test "admin sees Verwaltung link in user dropdown" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get verwaltung_verleihende_path
    assert_response :success
    assert_select ".dropdown-menu a[href='/verwaltung']", text: "Verwaltung"
  end

  test "member does not see Verwaltung link in user dropdown" do
    member = create(:user, department: @department)
    sign_in member

    get verwaltung_verleihende_path
    assert_response :success
    assert_select ".dropdown-menu a[href='/verwaltung']", false,
      "Member should not see Verwaltung link"
  end
end
