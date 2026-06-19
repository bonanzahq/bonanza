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

  test "browser checkout flow: rendered form params yield correct accessories per line_item in printable agreement" do
    parent_a = create(:parent_item, department: @department, name: "Kamera")
    item_a = create(:item, parent_item: parent_a, quantity: 5, uid: "CAM-001")
    acc_a1 = create(:accessory, parent_item: parent_a, name: "Akku A1")
    acc_a2 = create(:accessory, parent_item: parent_a, name: "Akku A2")

    parent_b = create(:parent_item, department: @department, name: "Stativ")
    item_b = create(:item, parent_item: parent_b, quantity: 5, uid: "TRI-001")
    acc_b1 = create(:accessory, parent_item: parent_b, name: "Tasche B1")
    acc_b2 = create(:accessory, parent_item: parent_b, name: "Tasche B2")

    borrower = create(:borrower, :with_tos)

    sign_in @user
    post lending_populate_path, params: { item_id: item_a.id, quantity: 1 }
    post lending_populate_path, params: { item_id: item_b.id, quantity: 1 }

    lending = Lending.find(session[:lending_id])
    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower.id, duration: 14)

    # GET the confirmation page exactly as a browser would.
    get checkout_state_path("confirmation")
    assert_response :success

    # Build the POST payload from the rendered HTML, the same way a browser
    # would submit it. This means a broken form (collisions on line_item index)
    # would produce a broken submission and surface end-to-end.
    doc = Nokogiri::HTML(@response.body)
    form_params = { duration: "14", line_items_attributes: {} }

    doc.css(".bnz-card").each do |card|
      ids = card.css("input[type=hidden][name*='[id]']").map { |i| [i["name"], i["value"]] }
      assert_equal 1, ids.size, "Each card must emit exactly one id field; got #{ids.inspect}"
      name, value = ids.first
      idx = name[/\[line_items_attributes\]\[(\d+)\]\[id\]/, 1]
      assert idx, "id field name did not match expected pattern: #{name}"

      checked_accessory_ids = card.css("input[type=checkbox][name*='accessory_ids'][checked]").map { |i| i["value"] }

      form_params[:line_items_attributes][idx] = {
        id: value,
        accessory_ids: [""] + checked_accessory_ids
      }
    end

    indices = form_params[:line_items_attributes].keys
    assert_equal indices.uniq.size, indices.size, "Form emitted duplicate line_item indices: #{indices.inspect}"
    assert_equal 2, indices.size, "Expected 2 line_item form sections; got #{indices.inspect}"

    # Simulate user unchecking some accessories: keep Akku A1 only on Kamera;
    # uncheck everything on Stativ.
    form_params[:line_items_attributes].each_value do |attrs|
      li = LineItem.find(attrs[:id])
      if li.item_id == item_a.id
        attrs[:accessory_ids] = ["", acc_a1.id.to_s]
      else
        attrs[:accessory_ids] = [""]
      end
    end

    patch update_checkout_path("confirmation"), params: { lending: form_params }
    assert_redirected_to lending_path

    lending.reload
    li_a = lending.line_items.find_by(item_id: item_a.id)
    li_b = lending.line_items.find_by(item_id: item_b.id)

    assert_equal [acc_a1.id], li_a.accessory_ids,
      "Kamera should have only Akku A1; got #{li_a.accessories.map(&:name).inspect}"
    assert_empty li_b.accessory_ids,
      "Stativ should have no accessories; got #{li_b.accessories.map(&:name).inspect}"

    get lending_agreement_path(lending.id, lending.token)
    assert_response :success

    rows = Nokogiri::HTML(@response.body).css("tbody tr").to_a
    row_a = rows.find { |r| r.text.include?("Kamera") }
    row_b = rows.find { |r| r.text.include?("Stativ") }
    assert row_a, "Expected printable agreement row for Kamera"
    assert row_b, "Expected printable agreement row for Stativ"

    assert_includes row_a.text, "Akku A1"
    assert_not_includes row_a.text, "Akku A2"
    assert_not_includes row_a.text, "Tasche B1"
    assert_not_includes row_a.text, "Tasche B2"

    assert_not_includes row_b.text, "Akku A1"
    assert_not_includes row_b.text, "Akku A2"
    assert_not_includes row_b.text, "Tasche B1"
    assert_not_includes row_b.text, "Tasche B2"
  end

  # Long-cart stress: emulates the production symptom where many items in a
  # single lending exposed the indexing collision bug. Each line item is given
  # a different accessory-selection pattern to ensure no cross-contamination
  # at scale.
  test "browser checkout flow with 8 line items keeps each line_item's accessories isolated" do
    parents = 5.times.map do |i|
      parent = create(:parent_item, department: @department, name: "Gear-#{i}")
      acc_count = i + 1 # 1, 2, 3, 4, 5 accessories
      accessories = acc_count.times.map { |j| create(:accessory, parent_item: parent, name: "Gear-#{i}-Acc-#{j}") }
      items = 2.times.map { |k| create(:item, parent_item: parent, quantity: 5, uid: "UID-#{i}-#{k}") }
      { parent: parent, accessories: accessories, items: items }
    end

    # Build a cart of 8 line_items mixing different parents (some parents used
    # twice via their second item) to exercise both unique and repeated parents.
    cart_items = [
      parents[0][:items][0], # Gear-0
      parents[1][:items][0], # Gear-1
      parents[2][:items][0], # Gear-2
      parents[3][:items][0], # Gear-3
      parents[4][:items][0], # Gear-4
      parents[1][:items][1], # Gear-1 second item — same parent as line 2
      parents[2][:items][1], # Gear-2 second item — same parent as line 3
      parents[4][:items][1]  # Gear-4 second item — same parent as line 5
    ]

    borrower = create(:borrower, :with_tos)

    sign_in @user
    cart_items.each { |item| post lending_populate_path, params: { item_id: item.id, quantity: 1 } }

    lending = Lending.find(session[:lending_id])
    assert_equal 8, lending.line_items.count

    lending.update_columns(state: Lending.states[:confirmation], borrower_id: borrower.id, duration: 14)

    get checkout_state_path("confirmation")
    assert_response :success

    doc = Nokogiri::HTML(@response.body)
    form_params = { duration: "14", line_items_attributes: {} }

    doc.css(".bnz-card").each do |card|
      ids = card.css("input[type=hidden][name*='[id]']").map { |i| [i["name"], i["value"]] }
      assert_equal 1, ids.size, "Each card must emit exactly one id field; got #{ids.inspect}"
      name, value = ids.first
      idx = name[/\[line_items_attributes\]\[(\d+)\]\[id\]/, 1]
      assert idx, "id field name did not match expected pattern: #{name}"
      checked_accessory_ids = card.css("input[type=checkbox][name*='accessory_ids'][checked]").map { |i| i["value"] }
      form_params[:line_items_attributes][idx] = { id: value, accessory_ids: [""] + checked_accessory_ids }
    end

    indices = form_params[:line_items_attributes].keys
    assert_equal indices.uniq.size, indices.size,
      "Form emitted duplicate line_item indices: #{indices.tally.select { |_, c| c > 1 }.inspect}"
    assert_equal 8, indices.size, "Expected 8 line_item form sections; got #{indices.size}"

    # Decide a deterministic, varied selection pattern per line item:
    # - line idx 0: keep all
    # - line idx 1: keep none
    # - line idx 2: keep first only
    # - line idx 3: keep last only
    # - line idx 4: keep every other accessory
    # - line idx 5: keep all (same parent as idx 1, but its own selection)
    # - line idx 6: keep none (same parent as idx 2, but its own selection)
    # - line idx 7: keep first only (same parent as idx 4, but its own selection)
    selection_pattern = lambda do |idx, available_ids|
      case idx
      when 0 then available_ids
      when 1 then []
      when 2 then available_ids.first(1)
      when 3 then available_ids.last(1)
      when 4 then available_ids.each_with_index.select { |_, i| i.even? }.map(&:first)
      when 5 then available_ids
      when 6 then []
      when 7 then available_ids.first(1)
      end
    end

    # Sort line items by id to match the rendering order (line_items.each_with_index
    # iterates the default association order which is by primary key).
    ordered_line_items = lending.line_items.order(:id).to_a
    expected = {}
    form_params[:line_items_attributes].each do |idx, attrs|
      li = ordered_line_items[idx.to_i]
      assert li, "Could not match form index #{idx} to a line_item"
      available = li.item.parent_item.accessories.map(&:id)
      chosen = selection_pattern.call(idx.to_i, available)
      attrs[:accessory_ids] = [""] + chosen.map(&:to_s)
      expected[li.id] = chosen.sort
    end

    patch update_checkout_path("confirmation"), params: { lending: form_params }
    assert_redirected_to lending_path

    lending.reload
    lending.line_items.each do |li|
      assert_equal expected[li.id], li.accessory_ids.sort,
        "LineItem #{li.id} (item=#{li.item.parent_item.name}) accessory_ids mismatch"
    end

    get lending_agreement_path(lending.id, lending.token)
    assert_response :success

    rows = Nokogiri::HTML(@response.body).css("tbody tr").to_a
    assert_equal 8, rows.size, "Expected 8 printable agreement rows"

    rows.zip(ordered_line_items).each do |row, li|
      expected_acc_names = li.accessories.map(&:name)
      forbidden_acc_names = Accessory.where.not(id: li.accessory_ids).pluck(:name)

      expected_acc_names.each do |name|
        assert_includes row.text, name,
          "Row for LineItem #{li.id} (#{li.item.parent_item.name}) missing expected accessory: #{name}"
      end
      forbidden_acc_names.each do |name|
        # Some accessories share names across parents in this test only if we
        # had constructed them that way — we didn't (names are unique with
        # Gear-i-Acc-j), so this assert is safe.
        assert_not_includes row.text, name,
          "Row for LineItem #{li.id} (#{li.item.parent_item.name}) leaked accessory: #{name}"
      end
    end
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
