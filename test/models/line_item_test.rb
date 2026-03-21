# ABOUTME: Tests for LineItem model business logic.
# ABOUTME: Covers quantity validation, decrease_item_quantity, apply_line_item_data_to_item, take_back.

require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    User.current_user = @user
    @parent_item = create(:parent_item, department: @department)
    @item = create(:item, parent_item: @parent_item, quantity: 5)
    @lending = create(:lending, user: @user, department: @department)
    @line_item = create(:line_item, item: @item, lending: @lending, quantity: 2)
  end

  # -- Validations --

  test "quantity must be an integer" do
    @line_item.quantity = 1.5
    assert_not @line_item.valid?
  end

  # -- decrease_item_quantity --

  test "decrease_item_quantity subtracts line item quantity from item" do
    @line_item.decrease_item_quantity
    assert_equal 3, @item.quantity
  end

  # -- apply_line_item_data_to_item --

  test "apply_line_item_data_to_item sets item to lent when quantity reaches zero" do
    @item.quantity = 0
    @line_item.apply_line_item_data_to_item("lent")

    assert_equal "lent", @item.status
  end

  test "apply_line_item_data_to_item does not set lent when quantity > 0" do
    @item.quantity = 3
    @line_item.apply_line_item_data_to_item("lent")

    assert_equal "available", @item.status
  end

  test "apply_line_item_data_to_item sets condition when provided" do
    @line_item.apply_line_item_data_to_item("lent", "broken")

    assert_equal "broken", @item.condition
  end

  test "apply_line_item_data_to_item sets note" do
    @line_item.apply_line_item_data_to_item("lent", nil, "scratched lens")

    assert_equal "scratched lens", @item.note
  end

  # -- take_back --

  test "take_back increases item quantity" do
    item = create(:item, parent_item: @parent_item, quantity: 0, uid: nil, status: :available)
    item.update_column(:status, Item.statuses[:lent])
    line_item = create(:line_item, item: item, lending: @lending, quantity: 2)
    line_item.reload

    line_item.take_back({ quantity: "2" })
    item.reload

    assert_equal 2, item.quantity
  end

  test "take_back sets returned_at on line item" do
    @item.update_columns(status: Item.statuses[:lent])
    @line_item.reload

    @line_item.take_back({ quantity: "1" })
    @line_item.reload

    assert @line_item.returned_at.present?
  end

  test "take_back rejects missing quantity" do
    result = @line_item.take_back({})
    assert_equal false, result
  end

  test "take_back rejects non-numeric quantity" do
    result = @line_item.take_back({ quantity: "abc" })
    assert_equal false, result
  end

  test "take_back rejects quantity exceeding lent amount" do
    result = @line_item.take_back({ quantity: "10" })
    assert_equal false, result
  end

  # -- dependent: :nullify --

  test "destroying line_item nullifies item_history references" do
    history = ItemHistory.create!(item: @item, user: @user, status: :lent, line_item: @line_item)
    @line_item.destroy!
    history.reload

    assert_nil history.line_item_id
  end

  test "take_back rejects multiple return for UID items" do
    @item.update_column(:uid, "SERIAL-001")
    @item.reload

    result = @line_item.take_back({ quantity: "2" })
    assert_equal false, result
  end
end
