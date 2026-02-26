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

  test "admin sees Werkstätten verwalten link on verwaltung page" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get borrowers_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", text: "Werkstätten verwalten"
  end

  test "leader sees Werkstätten verwalten link on verwaltung page" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get borrowers_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", text: "Werkstätten verwalten"
  end

  test "member does not see Werkstätten verwalten link on verwaltung page" do
    member = create(:user, department: @department)
    sign_in member

    get borrowers_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", false,
      "Member should not see Werkstätten verwalten link"
  end
end
