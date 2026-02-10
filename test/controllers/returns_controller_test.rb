# ABOUTME: Integration tests for ReturnsController.
# ABOUTME: Covers index rendering, take_back action, and authorization.

require "test_helper"

class ReturnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department, staffed: true)
    @user = create(:user, department: @department)
    User.current_user = @user

    @borrower = create(:borrower, :with_tos)
    @lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    @parent_item = create(:parent_item, department: @department)
    @item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    @line_item = create(:line_item, lending: @lending, item: @item, quantity: 1)
  end

  # -- index --

  test "index requires authentication" do
    get return_path
    assert_redirected_to new_user_session_path
  end

  test "index returns 200 for authenticated member" do
    sign_in @user
    get return_path
    assert_response :success
  end

  test "index renders with pending returns" do
    sign_in @user
    get return_path
    assert_response :success
    assert_select "body"
  end

  test "index renders with overdue returns" do
    @lending.update_columns(lent_at: 30.days.ago, duration: 7)
    sign_in @user
    get return_path
    assert_response :success
  end

  test "index renders empty state when no returns" do
    @line_item.update_column(:returned_at, Time.current)
    @lending.update_column(:returned_at, Time.current)

    sign_in @user
    get return_path
    assert_response :success
  end

  test "guest can read index" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    get return_path
    assert_response :success
  end

  # -- take_back --

  test "take_back returns item and sets returned_at" do
    sign_in @user
    post take_back_path, params: { line_item_id: @line_item.id, quantity: "1" }

    @line_item.reload
    @item.reload
    assert @line_item.returned_at.present?
    assert_equal 1, @item.quantity
  end

  test "take_back rejects missing quantity" do
    sign_in @user
    post take_back_path, params: { line_item_id: @line_item.id }
    assert_redirected_to return_path
    assert flash[:alert].present?
  end

  test "take_back guest cannot take back items" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    post take_back_path, params: { line_item_id: @line_item.id, quantity: "1" }
    assert_redirected_to public_home_page_path
  end
end
