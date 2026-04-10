# ABOUTME: Integration tests for the force_close controller action.
# ABOUTME: Verifies authorization, orphaned lending closure, and error handling.

require "test_helper"

class LendingForceCloseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department, staffed: true)
    @user = create(:user, department: @department)
    @admin = create(:user, :admin, department: @department)
    User.current_user = @user
    @parent_item = create(:parent_item, department: @department)
  end

  test "force_close requires authentication" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    patch force_close_lending_path(lending), params: { reason: "test" }
    assert_redirected_to new_user_session_path
  end

  test "force_close closes lending as admin" do
    sign_in @admin
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    li = create(:line_item, lending: lending, item: item, quantity: 1)

    patch force_close_lending_path(lending), params: { reason: "Admin override" }

    lending.reload
    li.reload
    assert lending.returned_at.present?
    assert li.returned_at.present?
    assert_includes lending.note, "Admin override"
    assert_redirected_to token_lending_path(lending, token: lending.token)
  end

  test "force_close closes lending as member" do
    sign_in @user
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    patch force_close_lending_path(lending), params: { reason: "Cleanup" }

    lending.reload
    assert lending.returned_at.present?
    assert_redirected_to token_lending_path(lending, token: lending.token)
  end

  test "force_close restores item quantity" do
    sign_in @admin
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 2)

    patch force_close_lending_path(lending), params: { reason: "Force close" }

    item.reload
    assert_equal 2, item.quantity
    assert_equal "available", item.status
  end

  test "force_close rejects guest users" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    patch force_close_lending_path(lending), params: { reason: "test" }

    assert_redirected_to public_home_page_path
    lending.reload
    assert_nil lending.returned_at
  end

  test "force_close rejects lending from different department" do
    other_dept = create(:department)
    other_user = create(:user, department: other_dept)
    sign_in @user
    other_parent = create(:parent_item, department: other_dept)
    item = create(:item, parent_item: other_parent, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: other_user, department: other_dept)
    create(:line_item, lending: lending, item: item, quantity: 1)

    patch force_close_lending_path(lending), params: { reason: "test" }
    assert_response :not_found
  end

  test "force_close shows error for already-returned lending" do
    sign_in @admin
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_column(:returned_at, Time.current)

    patch force_close_lending_path(lending), params: { reason: "test" }

    assert_redirected_to token_lending_path(lending, token: lending.token)
    assert_equal "Ausleihe ist bereits zurückgegeben.", flash[:alert]
  end

  test "force_close requires a reason" do
    sign_in @admin
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    patch force_close_lending_path(lending), params: { reason: "" }

    assert_redirected_to token_lending_path(lending, token: lending.token)
    assert flash[:alert].present?
    lending.reload
    assert_nil lending.returned_at
  end
end
