# ABOUTME: Integration tests for CheckoutController.
# ABOUTME: Covers before_action guards, state machine flow, and checkout completion.

require "test_helper"

class CheckoutControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department, staffed: true)
    @user = create(:user, department: @department)
    User.current_user = @user

    @parent_item = create(:parent_item, department: @department)
    @item = create(:item, parent_item: @parent_item, quantity: 5)
  end

  # Helper: populate cart to establish session with line items
  def populate_cart
    sign_in @user
    post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    session[:lending_id]
  end

  # -- index: authentication --

  test "index requires authentication" do
    get checkout_path
    assert_redirected_to new_user_session_path
  end

  test "index denies access to guest" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    # populate to establish lending in session
    post lending_populate_path, params: { item_id: @item.id, quantity: 1 }
    get checkout_state_path("borrower")
    assert_redirected_to public_home_page_path
  end

  # -- index: before_action guards --

  test "index redirects to lending_path without line items" do
    sign_in @user
    get checkout_state_path("borrower")
    assert_redirected_to lending_path
  end

  test "index redirects when department is unstaffed" do
    populate_cart
    @department.update_column(:staffed, false)

    get checkout_state_path("borrower")
    assert_redirected_to lending_path
  end

  test "index auto-advances cart state to borrower and redirects" do
    populate_cart

    get checkout_path
    assert_redirected_to checkout_state_path("borrower")
  end

  test "index renders borrower state" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])

    get checkout_state_path("borrower")
    assert_response :success
  end

  test "borrower state shows borrower list without search query" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])

    get checkout_state_path("borrower")
    assert_response :success
    assert_select "div.results.borrowers"
    assert_select "p i.text-muted", false, "Should not show 'search for borrowers' prompt"
  end

  test "index rejects skipping to confirmation from borrower" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])

    get checkout_state_path("confirmation")
    assert_redirected_to checkout_state_path("borrower")
  end

  test "index redirects completed lending away from checkout" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    borrower = create(:borrower, :with_tos)
    lending.update_columns(
      state: Lending.states[:completed],
      borrower_id: borrower.id,
      duration: 14,
      lent_at: Time.current
    )

    get checkout_state_path("confirmation")
    assert_redirected_to lending_path
  end

  # -- update --

  test "update without params redirects with alert" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])

    patch update_checkout_path("borrower")
    assert_redirected_to checkout_state_path("borrower")
    assert flash[:alert].present?
  end

  test "update advances from borrower to confirmation with borrower_id" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])
    borrower = create(:borrower, :with_tos)

    patch update_checkout_path("borrower"), params: { lending: { borrower_id: borrower.id } }
    lending.reload
    assert_equal "confirmation", lending.state
    assert_redirected_to checkout_state_path("confirmation")
  end

  test "update completes from confirmation and clears session" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    borrower = create(:borrower, :with_tos)
    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower.id, duration: 14)

    patch update_checkout_path("confirmation"), params: {
      lending: { borrower_id: borrower.id, duration: 14 }
    }

    lending.reload
    assert_equal "completed", lending.state
    assert_nil session[:lending_id]
    assert_redirected_to lending_path
  end

end
