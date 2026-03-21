# ABOUTME: View tests for the _bnz_item lending partial.
# ABOUTME: Verifies nil-safe rendering when items lack line_items or lending data.

require "test_helper"

class LendingBnzItemPartialTest < ActionView::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @department = create(:department, staffed: true)
    @user = create(:user, department: @department)
    @parent_item = create(:parent_item, department: @department)
    @lending = create(:lending, user: @user, department: @department)
    sign_in @user
  end

  test "renders lent item without line_items without error" do
    item = create(:item, :lent, parent_item: @parent_item)

    render partial: "lending/bnz_item", locals: { item: item }

    assert_match "ausgeliehen", rendered
    assert_no_match "von", rendered
  end

  test "renders lent item with complete lending data" do
    borrower = create(:borrower, :with_tos)
    completed_lending = create(:lending, :completed, user: @user, department: @department, borrower: borrower)
    item = create(:item, :lent, parent_item: @parent_item)
    create(:line_item, lending: completed_lending, item: item, quantity: 1)

    render partial: "lending/bnz_item", locals: { item: item }

    assert_match "ausgeliehen", rendered
    assert_match borrower.fullname, rendered
  end

  test "renders lent item when lending has no borrower" do
    lending_no_borrower = create(:lending, user: @user, department: @department, borrower: nil)
    lending_no_borrower.update_columns(lent_at: Time.current, duration: 14)
    item = create(:item, :lent, parent_item: @parent_item)
    create(:line_item, lending: lending_no_borrower, item: item, quantity: 1)

    render partial: "lending/bnz_item", locals: { item: item }

    assert_match "ausgeliehen", rendered
    assert_no_match "von", rendered
  end

  test "renders available item with add-to-cart form" do
    item = create(:item, parent_item: @parent_item)

    render partial: "lending/bnz_item", locals: { item: item }

    assert_match "abschicken", rendered
  end
end
