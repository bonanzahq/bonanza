# ABOUTME: Integration tests for LendingController.
# ABOUTME: Covers cart workflow, populate, remove, empty, destroy, show, and change_duration.

require "test_helper"

class LendingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department, staffed: true)
    @user = create(:user, department: @department)
    User.current_user = @user

    @parent_item = create(:parent_item, department: @department)
    @item = create(:item, parent_item: @parent_item, quantity: 5)
  end

  # -- index --

  test "index requires authentication" do
    get lending_path
    assert_redirected_to new_user_session_path
  end

  test "index returns 200 for authenticated member" do
    sign_in @user
    get lending_path
    assert_response :success
  end

  # -- show --

  test "show with valid token renders for signed-in user" do
    lending = create(:lending, :completed, user: @user, department: @department)
    sign_in @user

    get token_lending_path(lending, token: lending.token)
    assert_response :success
  end

  test "show with valid token renders show_public when not signed in" do
    lending = create(:lending, :completed, user: @user, department: @department)

    get token_lending_path(lending, token: lending.token)
    assert_response :success
  end

  test "show with invalid token redirects" do
    lending = create(:lending, :completed, user: @user, department: @department)
    sign_in @user

    get token_lending_path(lending, token: "wrong-token")
    assert_redirected_to lending_path
  end

  # -- show_printable_agreement --

  test "show_printable_agreement renders with print layout" do
    borrower = create(:borrower, :with_tos)
    lending = create(:lending, :completed, user: @user, department: @department, borrower: borrower)
    sign_in @user

    get lending_agreement_path(lending, token: lending.token)
    assert_response :success
  end

  test "show_printable_agreement with invalid token redirects" do
    lending = create(:lending, :completed, user: @user, department: @department)
    sign_in @user

    get lending_agreement_path(lending, token: "bad-token")
    assert_redirected_to lending_path
  end

  # -- populate --

  test "populate adds item to cart" do
    sign_in @user

    assert_difference "LineItem.count", 1 do
      post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    end
    assert_redirected_to lending_path
  end

  test "populate rejects unavailable item" do
    @item.update_column(:status, Item.statuses[:lent])
    sign_in @user

    assert_no_difference "LineItem.count" do
      post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    end
  end

  test "populate rejects item from different department" do
    other_dept = create(:department)
    other_parent = create(:parent_item, department: other_dept)
    other_item = create(:item, parent_item: other_parent)
    sign_in @user

    assert_no_difference "LineItem.count" do
      post lending_populate_path, params: { item_id: other_item.id, quantity: 1 }
    end
  end

  test "populate rejects zero quantity" do
    sign_in @user

    assert_no_difference "LineItem.count" do
      post lending_populate_path, params: { item_id: @item.id, quantity: 0 }
    end
  end

  test "populate rejects when department is unstaffed" do
    @department.update_column(:staffed, false)
    sign_in @user

    assert_no_difference "LineItem.count" do
      post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    end
  end

  # -- remove_line_item --

  test "remove_line_item removes item from cart" do
    sign_in @user
    post lending_populate_path, params: { item_id: @item.id, quantity: 1 }

    lending = Lending.find(session[:lending_id])
    line_item = lending.line_items.first

    # add a second item so cart still has items after removal
    item2 = create(:item, parent_item: @parent_item, quantity: 3)
    post lending_populate_path, params: { item_id: item2.id, quantity: 1 }

    assert_difference "LineItem.count", -1 do
      delete remove_line_item_path(line_item_id: line_item.id), as: :turbo_stream
    end
  end

  test "remove_line_item clears session when last item removed" do
    sign_in @user
    post lending_populate_path, params: { item_id: @item.id, quantity: 1 }

    lending = Lending.find(session[:lending_id])
    line_item = lending.line_items.first

    delete remove_line_item_path(line_item_id: line_item.id), as: :turbo_stream
    assert_nil session[:lending_id]
  end

  # -- empty --

  test "empty clears session and destroys non-completed lending" do
    sign_in @user
    post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    lending_id = session[:lending_id]

    put empty_cart_path
    assert_response :see_other
    assert_redirected_to lending_path
    assert_nil session[:lending_id]
    assert_not Lending.exists?(lending_id)
  end

  # -- destroy --

  test "destroy eradicates lending and restores items" do
    sign_in @user
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: @item, quantity: 2)
    @item.update_columns(quantity: 3, status: Item.statuses[:lent])

    delete lending_destroy_path(lending)
    assert_response :see_other

    @item.reload
    assert_equal 5, @item.quantity
    assert_not Lending.exists?(lending.id)
  end

  test "destroy rejects lending from wrong department" do
    other_dept = create(:department)
    other_user = create(:user, department: other_dept)
    other_lending = create(:lending, :completed, user: other_user, department: other_dept)
    sign_in @user

    delete lending_destroy_path(other_lending)
    assert_response :not_found
  end

  # -- authorization --

  test "guest can view lending index" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    get lending_path
    assert_response :success
  end

  test "guest cannot populate cart" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    assert_redirected_to public_home_page_path
  end

  test "guest cannot destroy lending" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    lending = create(:lending, :completed, user: @user, department: @department)
    delete lending_destroy_path(lending)
    assert_redirected_to public_home_page_path
    assert Lending.exists?(lending.id)
  end

  test "guest cannot change duration" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_columns(lent_at: 1.day.ago, duration: 14)
    patch change_lending_duration_path(lending), params: { lending: { duration: 30 } }
    assert_redirected_to public_home_page_path
    assert_equal 14, lending.reload.duration
  end

  # -- change_duration --

  test "change_duration updates duration and resets notification_counter" do
    sign_in @user
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_columns(lent_at: 1.day.ago, duration: 14, notification_counter: 2)

    patch change_lending_duration_path(lending), params: { lending: { duration: 30 } }
    assert_redirected_to token_lending_path(lending, token: lending.token)

    lending.reload
    assert_equal 30, lending.duration
    assert_equal 0, lending.notification_counter
  end

  test "change_duration rejects past return date" do
    sign_in @user
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_columns(lent_at: 30.days.ago, duration: 14)

    patch change_lending_duration_path(lending), params: { lending: { duration: 7 } }

    lending.reload
    assert_equal 14, lending.duration
  end
end
