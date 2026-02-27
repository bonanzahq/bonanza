# ABOUTME: Tests authorization for the statistics dashboard.
# ABOUTME: Verifies members and above can access statistics but guests cannot.

require "test_helper"

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
  end

  test "unauthenticated user cannot access statistics" do
    get verwaltung_statistik_path
    assert_redirected_to new_user_session_path
  end

  test "member can access statistics" do
    member = create(:user, department: @department)
    sign_in member
    get verwaltung_statistik_path
    assert_response :success
  end

  test "leader can access statistics" do
    leader = create(:user, :leader, department: @department)
    sign_in leader
    get verwaltung_statistik_path
    assert_response :success
  end

  test "admin can access statistics" do
    admin = create(:user, :admin, department: @department)
    sign_in admin
    get verwaltung_statistik_path
    assert_response :success
  end

  test "guest cannot access statistics" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    get verwaltung_statistik_path
    assert_redirected_to public_home_page_path
  end
end
