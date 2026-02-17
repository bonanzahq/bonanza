# ABOUTME: Integration tests for ParentItemsController.
# ABOUTME: Covers show action and exercises get_weekly_lending_activity SQL query.

require "test_helper"

class ParentItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department, staffed: true)
    @user = create(:user, department: @department)
    User.current_user = @user
    @parent_item = create(:parent_item, department: @department)
    @item = create(:item, parent_item: @parent_item, quantity: 5)
  end

  # -- show --

  test "show requires authentication" do
    get parent_item_path(@parent_item)
    assert_redirected_to new_user_session_path
  end

  test "show returns 200 for authenticated user" do
    sign_in @user
    get parent_item_path(@parent_item)
    assert_response :success
  end

  test "show returns 200 with lending activity data" do
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: @item)
    
    sign_in @user
    get parent_item_path(@parent_item)
    assert_response :success
  end
end
