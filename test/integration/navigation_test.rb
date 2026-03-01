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

  test "member sees Verwaltung link in user dropdown" do
    member = create(:user, department: @department)
    sign_in member

    get verwaltung_verleihende_path
    assert_response :success
    assert_select ".dropdown-menu a[href='/verwaltung']", text: "Verwaltung"
  end

  test "leader sees Verwaltung link in user dropdown" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get verwaltung_verleihende_path
    assert_response :success
    assert_select ".dropdown-menu a[href='/verwaltung']", text: "Verwaltung"
  end

  test "guest does not see Verwaltung link in user dropdown" do
    guest = create(:user, :guest, department: @department)
    sign_in guest

    get edit_user_path(guest)
    assert_response :success
    assert_select ".dropdown-menu a[href='/verwaltung']", false,
      "Guest should not see Verwaltung link"
  end

  test "admin sees Werkstätten link on verwaltung page" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get borrowers_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", text: "Werkstätten"
  end

  test "leader sees Werkstätten link on verwaltung page" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get borrowers_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", text: "Werkstätten"
  end

  test "member sees Werkstätten link on verwaltung page" do
    member = create(:user, department: @department)
    sign_in member

    get borrowers_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", text: "Werkstätten"
  end

  # -- department switcher --

  test "multi-department user sees department switcher dropdown in logo" do
    # Create a new dept and user — dept2 will be created AFTER user to trigger auto-add
    dept1 = create(:department)
    user = create(:user, department: dept1)
    create(:department) # before_create callback auto-adds user to this dept

    sign_in user
    get verwaltung_verleihende_path
    assert_response :success

    assert_select "h1#logo .dropdown button.dropdown-toggle"
    assert_select "h1#logo ul.dropdown-menu"
  end

  test "single-department user sees plain department name without switcher in logo" do
    dept1 = create(:department)
    user = create(:user, department: dept1)
    # No additional departments created after user, so user stays single-dept

    sign_in user
    get verwaltung_verleihende_path
    assert_response :success

    assert_select "h1#logo span", text: dept1.name
    assert_select "h1#logo .dropdown", false,
      "Single-department user should not see department switcher dropdown"
  end
end
