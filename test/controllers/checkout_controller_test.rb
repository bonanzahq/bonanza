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
    # Elasticsearch is not available in test, so @borrowers will be Borrower.none.
    # This test only verifies the page renders without crashing and the results
    # container is present. Actual borrower rendering requires a running ES instance.
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])

    get checkout_state_path("borrower")
    assert_response :success
    assert_select "div.results.borrowers"
    assert_select "p i.text-muted", false, "Should not show 'no results' when no search query given"
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

  test "select_borrower sets borrower without advancing state" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])
    borrower = create(:borrower, :with_tos)

    patch select_checkout_borrower_path, params: { lending: { borrower_id: borrower.id } }
    assert_redirected_to checkout_state_path("borrower")

    lending.reload
    assert_equal borrower.id, lending.borrower_id
    assert_equal "borrower", lending.state
  end

  test "select_borrower allows changing borrower from confirmation state" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    borrower_a = create(:borrower, :with_tos)
    borrower_b = create(:borrower, :with_tos)
    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower_a.id)

    patch select_checkout_borrower_path, params: { lending: { borrower_id: borrower_b.id } }

    lending.reload
    assert_equal borrower_b.id, lending.borrower_id
    assert_equal "borrower", lending.state
    assert_redirected_to checkout_state_path("borrower")
  end

  test "select_borrower shows error when update fails" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])
    borrower_no_tos = create(:borrower) # no :with_tos trait = tos_accepted is false

    patch select_checkout_borrower_path, params: { lending: { borrower_id: borrower_no_tos.id } }

    lending.reload
    assert_nil lending.borrower_id
    assert flash[:alert].present?
  end

  test "borrower state shows Weiter button in sidebar when borrower is assigned" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    borrower = create(:borrower, :with_tos)
    lending.update_columns(state: Lending.states[:borrower], borrower_id: borrower.id)

    get checkout_state_path("borrower")
    assert_response :success
    assert_select ".sidebar-cart .checkout-actions form[action='#{update_checkout_path("borrower")}'] button", text: "Weiter"
  end

  test "borrower state does not show Weiter button when no borrower is assigned" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])

    get checkout_state_path("borrower")
    assert_response :success
    assert_select ".sidebar-cart .checkout-actions", count: 0
  end

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

  # -- accessory indexing (P0 bug #290) --

  # View test: fails before the fix because the form uses the inner accessory
  # index (i) as the key, causing collisions across line_items.
  test "confirmation form renders exactly one id field per line_item at a unique index" do
    parent_a = create(:parent_item, department: @department)
    item_a = create(:item, parent_item: parent_a, quantity: 5)
    create(:accessory, parent_item: parent_a)
    create(:accessory, parent_item: parent_a)

    parent_b = create(:parent_item, department: @department)
    item_b = create(:item, parent_item: parent_b, quantity: 5)
    create(:accessory, parent_item: parent_b)

    borrower = create(:borrower, :with_tos)

    sign_in @user
    post lending_populate_path, params: { item_id: item_a.id, quantity: 1 }
    post lending_populate_path, params: { item_id: item_b.id, quantity: 1 }

    lending = Lending.find(session[:lending_id])
    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower.id, duration: 14)

    get checkout_state_path("confirmation")
    assert_response :success

    # Each line_item must produce exactly one id hidden field at its own unique index.
    assert_select "input[name='lending[line_items_attributes][0][id]']", count: 1
    assert_select "input[name='lending[line_items_attributes][1][id]']", count: 1
    # No overflow to a third index.
    assert_select "input[name='lending[line_items_attributes][2][id]']", count: 0
  end

  test "checkout completion stores accessories on the correct line_item" do
    parent_a = create(:parent_item, department: @department)
    item_a = create(:item, parent_item: parent_a, quantity: 5)
    acc_a1 = create(:accessory, parent_item: parent_a)
    acc_a2 = create(:accessory, parent_item: parent_a)

    parent_b = create(:parent_item, department: @department)
    item_b = create(:item, parent_item: parent_b, quantity: 5)
    acc_b1 = create(:accessory, parent_item: parent_b)

    borrower = create(:borrower, :with_tos)

    sign_in @user
    post lending_populate_path, params: { item_id: item_a.id, quantity: 1 }
    post lending_populate_path, params: { item_id: item_b.id, quantity: 1 }

    lending = Lending.find(session[:lending_id])
    line_items = lending.line_items.order(:id)
    li_a = line_items.find { |li| li.item_id == item_a.id }
    li_b = line_items.find { |li| li.item_id == item_b.id }
    li_a_idx = line_items.index(li_a)
    li_b_idx = line_items.index(li_b)

    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower.id, duration: 14)

    patch update_checkout_path("confirmation"), params: {
      lending: {
        duration: 14,
        line_items_attributes: {
          li_a_idx.to_s => { id: li_a.id, accessory_ids: ["", acc_a1.id.to_s] },
          li_b_idx.to_s => { id: li_b.id, accessory_ids: ["", acc_b1.id.to_s] }
        }
      }
    }

    assert_redirected_to lending_path
    li_a.reload
    li_b.reload

    assert_equal [acc_a1.id], li_a.accessory_ids
    assert_equal [acc_b1.id], li_b.accessory_ids
    assert_not_includes li_a.accessory_ids, acc_b1.id
    assert_not_includes li_b.accessory_ids, acc_a1.id
    assert_not_includes li_b.accessory_ids, acc_a2.id
  end

  test "checkout completion clears all accessories when sentinel is sent with no selections" do
    parent_a = create(:parent_item, department: @department)
    item_a = create(:item, parent_item: parent_a, quantity: 5)
    acc_a1 = create(:accessory, parent_item: parent_a)
    acc_a2 = create(:accessory, parent_item: parent_a)

    borrower = create(:borrower, :with_tos)

    sign_in @user
    post lending_populate_path, params: { item_id: item_a.id, quantity: 1 }

    lending = Lending.find(session[:lending_id])
    li_a = lending.line_items.order(:id).first
    li_a.accessories << acc_a1
    li_a.accessories << acc_a2

    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower.id, duration: 14)

    patch update_checkout_path("confirmation"), params: {
      lending: {
        duration: 14,
        line_items_attributes: {
          "0" => { id: li_a.id, accessory_ids: [""] }
        }
      }
    }

    li_a.reload
    assert_empty li_a.accessory_ids
  end

  # -- strong parameters --

  test "select_borrower ignores unpermitted params" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])
    borrower = create(:borrower, :with_tos)

    patch select_checkout_borrower_path, params: {
      lending: { borrower_id: borrower.id, duration: 99, note: "injected" }
    }

    lending.reload
    assert_equal borrower.id, lending.borrower_id
    assert_nil lending.duration
    assert_nil lending.note
  end

  test "update ignores unpermitted params in lending" do
    lending_id = populate_cart
    lending = Lending.find(lending_id)
    lending.update_column(:state, Lending.states[:borrower])
    borrower = create(:borrower, :with_tos)

    patch update_checkout_path("borrower"), params: {
      lending: { borrower_id: borrower.id, user_id: 999 }
    }

    lending.reload
    assert_not_equal 999, lending.user_id
  end

end
