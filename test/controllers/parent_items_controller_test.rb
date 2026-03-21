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

  test "show handles item history with nil line_item" do
    ItemHistory.create!(item: @item, user: @user, status: :lent, line_item: nil)

    sign_in @user
    get parent_item_path(@parent_item)
    assert_response :success
  end

  test "guest does not see borrower name in item history" do
    borrower = create(:borrower, :with_tos)
    lending = create(:lending, :completed, user: @user, department: @department, borrower: borrower)
    line_item = create(:line_item, lending: lending, item: @item)
    ItemHistory.create!(item: @item, user: @user, status: :lent, line_item: line_item)

    guest = create(:user, :guest, department: @department)
    sign_in guest
    get parent_item_path(@parent_item)
    assert_response :success
    assert_no_match borrower.fullname, response.body
  end

  # -- move (via update) --

  test "member can move parent item to another department they belong to" do
    # Department before_create callback auto-adds @user to the new dept
    target_dept = create(:department)

    sign_in @user
    patch parent_item_path(@parent_item), params: { parent_item: { department_id: target_dept.id, name: @parent_item.name } }

    assert_redirected_to borrowers_path
    assert_equal "Artikel wurde aktualisiert und verschoben.", flash[:notice]
    assert_equal target_dept, @parent_item.reload.department
  end

  test "cannot move parent item with lent items" do
    target_dept = create(:department)
    create(:item, parent_item: @parent_item, status: :lent)

    sign_in @user
    patch parent_item_path(@parent_item), params: { parent_item: { department_id: target_dept.id, name: @parent_item.name } }

    assert_response :redirect
    assert_equal @department, @parent_item.reload.department
  end

  test "cannot move parent item to department user does not belong to" do
    target_dept = create(:department)
    # @user was auto-added by before_create; destroy that membership
    @user.department_memberships.find_by(department: target_dept).destroy

    sign_in @user
    patch parent_item_path(@parent_item), params: { parent_item: { department_id: target_dept.id, name: @parent_item.name } }

    assert_response :redirect
    assert_equal @department, @parent_item.reload.department
  end

  test "guest cannot move parent item" do
    target_dept = create(:department)
    guest = create(:user, :guest, department: @department)

    sign_in guest
    patch parent_item_path(@parent_item), params: { parent_item: { department_id: target_dept.id, name: @parent_item.name } }

    assert_response :redirect
    assert_equal @department, @parent_item.reload.department
  end

  test "unauthenticated user is redirected to login when moving parent item" do
    target_dept = create(:department)

    patch parent_item_path(@parent_item), params: { parent_item: { department_id: target_dept.id, name: @parent_item.name } }

    assert_redirected_to new_user_session_path
  end

  test "update with department change and other field changes saves both" do
    target_dept = create(:department)
    new_name = "Updated Name"

    sign_in @user
    patch parent_item_path(@parent_item), params: { parent_item: { department_id: target_dept.id, name: new_name } }

    assert_redirected_to borrowers_path
    @parent_item.reload
    assert_equal target_dept, @parent_item.department
    assert_equal new_name, @parent_item.name
  end

  test "update without department_id param works normally" do
    new_name = "Normal Update"

    sign_in @user
    patch parent_item_path(@parent_item), params: { parent_item: { name: new_name } }

    assert_redirected_to parent_item_path(@parent_item)
    assert_equal "Parent item was successfully updated.", flash[:notice]
    assert_equal new_name, @parent_item.reload.name
    assert_equal @department, @parent_item.reload.department
  end

  # -- links (nested attributes) --

  test "create with nested links saves links" do
    sign_in @user
    assert_difference "Link.count", 1 do
      post parent_items_path, params: {
        parent_item: {
          name: "Camera With Links",
          links_attributes: { "0" => { url: "https://example.com", title: "Manual" } }
        }
      }
    end
    link = Link.last
    assert_equal "https://example.com", link.url
    assert_equal "Manual", link.title
  end

  test "update adds a link via nested attributes" do
    sign_in @user
    assert_difference "Link.count", 1 do
      patch parent_item_path(@parent_item), params: {
        parent_item: {
          name: @parent_item.name,
          links_attributes: { "0" => { url: "https://wiki.example.com", title: "Wiki" } }
        }
      }
    end
    assert_equal "https://wiki.example.com", @parent_item.links.last.url
  end

  test "update removes a link via _destroy" do
    link = create(:link, parent_item: @parent_item)
    sign_in @user
    assert_difference "Link.count", -1 do
      patch parent_item_path(@parent_item), params: {
        parent_item: {
          name: @parent_item.name,
          links_attributes: { "0" => { id: link.id, _destroy: "1" } }
        }
      }
    end
    assert_not Link.exists?(link.id)
  end

  test "show displays links for a parent item" do
    create(:link, parent_item: @parent_item, url: "https://docs.example.com", title: "Docs")
    sign_in @user
    get parent_item_path(@parent_item)
    assert_response :success
    assert_match "https://docs.example.com", response.body
    assert_match "Docs", response.body
  end

  test "link url is auto-prepended with http:// when scheme is missing" do
    sign_in @user
    post parent_items_path, params: {
      parent_item: {
        name: "Bare URL Item",
        links_attributes: { "0" => { url: "example.com/manual", title: "" } }
      }
    }
    link = Link.last
    assert_equal "http://example.com/manual", link.url
  end

  # -- strong parameters --

  test "create ignores unpermitted params in parent_item" do
    sign_in @user
    post parent_items_path, params: {
      parent_item: { name: "Test Item", evil_field: "hacked" }
    }
    assert_response :redirect
  end

  test "update ignores unpermitted params in parent_item" do
    sign_in @user
    patch parent_item_path(@parent_item), params: {
      parent_item: { name: "Updated", evil_field: "hacked" }
    }
    assert_redirected_to parent_item_path(@parent_item)
    assert_equal "Updated", @parent_item.reload.name
  end
end
