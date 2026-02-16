# ABOUTME: Tests for main navigation layout elements.
# ABOUTME: Verifies Verwaltung link appears in main nav for authorized users.

require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
  end

  test "admin sees Verwaltung link in main navigation" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get lending_path
    assert_response :success
    assert_select "nav.main-nav a[href='/verwaltung']", text: "Verwaltung"
  end

  test "leader sees Verwaltung link in main navigation" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get lending_path
    assert_response :success
    assert_select "nav.main-nav a[href='/verwaltung']", text: "Verwaltung"
  end

  test "member does not see Verwaltung link in main navigation" do
    member = create(:user, department: @department)
    sign_in member

    get lending_path
    assert_response :success
    assert_select "nav.main-nav a[href='/verwaltung']", false, "Member should not see Verwaltung link"
  end

  test "Verwaltung link is not in user dropdown menu" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get lending_path
    assert_response :success
    assert_select ".dropdown-menu a[href='/verwaltung']", false,
      "Verwaltung link should not be in the user dropdown"
  end
end
