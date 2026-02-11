# ABOUTME: Tests for Item model business logic.
# ABOUTME: Covers enums, validations, soft delete, resurrection, history tracking.

require "test_helper"

class ItemTest < ActiveSupport::TestCase
  setup do
    @item = create(:item)
  end

  # -- Enums --

  test "status enum has expected values" do
    assert_equal({ "available" => 0, "lent" => 1, "returned" => 2, "unavailable" => 3, "deleted" => 4 }, Item.statuses)
  end

  test "condition enum has expected values" do
    assert_equal({ "flawless" => 0, "flawed" => 1, "broken" => 2 }, Item.conditions)
  end

  # -- Validations --

  test "quantity must be an integer" do
    @item.quantity = 1.5
    assert_not @item.valid?
  end

  test "quantity must be >= 0" do
    @item.quantity = -1
    assert_not @item.valid?
  end

  test "quantity of zero is valid" do
    @item.quantity = 0
    assert @item.valid?
  end

  # -- Lent protection --

  test "lent item cannot be changed" do
    @item.update_column(:status, Item.statuses[:lent])
    @item.reload
    @item.note = "trying to change"

    assert_not @item.valid?
    assert @item.errors[:base].any? { |e| e.include?("ausgeliehen") }
  end

  test "lent item can have its status changed" do
    @item.update_column(:status, Item.statuses[:lent])
    @item.reload
    @item.status = :available

    assert @item.valid?
  end

  # -- Soft delete --

  test "item with multiple history records is soft-deleted" do
    # First history record is created on initial save.
    # Create a second one by changing the note.
    @item.update!(note: "changed")
    assert @item.item_histories.count > 1

    @item.destroy

    assert @item.persisted?
    assert @item.deleted?
  end

  test "item with single history record is hard-deleted" do
    assert_equal 1, @item.item_histories.count

    item_id = @item.id
    @item.destroy

    assert_nil Item.find_by(id: item_id)
  end

  # -- Resurrect --

  test "resurrect restores deleted item to available" do
    @item.update!(note: "changed")
    @item.destroy
    assert @item.deleted?

    @item.resurrect

    assert @item.available?
  end

  test "resurrect on non-deleted item adds error" do
    @item.resurrect

    assert @item.errors[:base].any?
  end

  # -- History tracking --

  test "history record created on item creation" do
    item = create(:item)
    history = item.item_histories.last

    assert_equal 1, item.item_histories.count
    assert_equal "created", history.status
    assert_equal item.quantity, history.quantity
  end

  test "history record tracks note changes" do
    @item.update!(note: "new note")

    history = @item.item_histories.reload.first
    assert_equal "new note", history.note
  end

  test "history record tracks condition changes" do
    @item.update!(condition: :broken)

    history = @item.item_histories.reload.first
    assert_equal "broken", history.condition
  end

  test "history record tracks status changes" do
    @item.update_column(:status, Item.statuses[:available])
    @item.reload
    @item.update!(status: :unavailable)

    history = @item.item_histories.reload.first
    assert_equal "unavailable", history.status
  end

  # -- user_adjusted_quantity --

  test "user_adjusted_quantity subtracts line item quantity" do
    lending = create(:lending)
    create(:line_item, item: @item, lending: lending, quantity: 3)
    @item.update_column(:quantity, 5)
    @item.reload

    assert_equal 2, @item.user_adjusted_quantity(lending)
  end

  test "user_adjusted_quantity returns full quantity when not in lending" do
    lending = create(:lending)

    assert_equal @item.quantity, @item.user_adjusted_quantity(lending)
  end
end
