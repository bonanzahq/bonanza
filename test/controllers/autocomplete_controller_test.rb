# ABOUTME: Tests authorization for autocomplete endpoints.
# ABOUTME: Verifies all authenticated users can access autocomplete data.

require "test_helper"

class AutocompleteControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @member = create(:user, department: @department)
    @guest = create(:user, :guest, department: @department)
    @parent_item = create(:parent_item, department: @department)
  end

  test "unauthenticated user cannot access items autocomplete" do
    get autocomplete_items_path
    assert_redirected_to new_user_session_path
  end

  test "member can access items autocomplete" do
    sign_in @member
    get autocomplete_items_path
    assert_response :success
  end

  test "guest can access items autocomplete" do
    sign_in @guest
    get autocomplete_items_path
    assert_response :success
  end

  test "member can access borrowers autocomplete" do
    sign_in @member
    get autocomplete_borrowers_path
    assert_response :success
  end

  test "guest can access borrowers autocomplete" do
    sign_in @guest
    get autocomplete_borrowers_path
    assert_response :success
  end
end
