# ABOUTME: Tests for ParentItem model business logic.
# ABOUTME: Covers department association, lent items check, dependent destroy.

require "test_helper"

class ParentItemTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @parent_item = create(:parent_item, department: @department)
  end

  test "factory creates a valid parent item" do
    assert @parent_item.persisted?
    assert_equal @department, @parent_item.department
  end

  test "has_lent_items? returns false when no items are lent" do
    create(:item, parent_item: @parent_item, status: :available)

    assert_not @parent_item.has_lent_items?
  end

  test "has_lent_items? returns true when an item is lent" do
    create(:item, parent_item: @parent_item, status: :lent)

    assert @parent_item.has_lent_items?
  end

  test "destroying parent_item destroys associated items" do
    create(:item, parent_item: @parent_item)

    assert_difference "Item.count", -1 do
      @parent_item.destroy
    end
  end

  test "items are ordered by id ascending" do
    item_a = create(:item, parent_item: @parent_item)
    item_b = create(:item, parent_item: @parent_item)

    assert_equal [item_a.id, item_b.id], @parent_item.items.reload.pluck(:id)
  end

  # -- Accessory guards when items are lent --

  test "accessories cannot be added when items are lent" do
    create(:item, parent_item: @parent_item, status: :lent)
    @parent_item.accessories.build(name: "New Cable")

    assert_not @parent_item.valid?
    assert @parent_item.errors[:base].any? { |e| e.include?("Zubehör") }
  end

  test "accessories cannot be edited when items are lent" do
    accessory = create(:accessory, parent_item: @parent_item)
    create(:item, parent_item: @parent_item, status: :lent)
    @parent_item.reload

    @parent_item.accessories.detect { |a| a.id == accessory.id }.name = "Changed Name"

    assert_not @parent_item.valid?
    assert @parent_item.errors[:base].any? { |e| e.include?("Zubehör") }
  end

  test "accessories cannot be removed when items are lent" do
    accessory = create(:accessory, parent_item: @parent_item)
    create(:item, parent_item: @parent_item, status: :lent)
    @parent_item.reload

    @parent_item.accessories.detect { |a| a.id == accessory.id }.mark_for_destruction

    assert_not @parent_item.valid?
    assert @parent_item.errors[:base].any? { |e| e.include?("Zubehör") }
  end

  test "updating with nil accessory name does not raise" do
    accessory = create(:accessory, parent_item: @parent_item)
    create(:item, parent_item: @parent_item, status: :lent)

    # Disabled form fields submit without name value (nil).
    # reject_accessory must handle this without raising.
    assert_nothing_raised do
      @parent_item.assign_attributes(
        accessories_attributes: { "0" => { id: accessory.id, name: nil } }
      )
    end
  end

  test "accessories can be changed when no items are lent" do
    accessory = create(:accessory, parent_item: @parent_item)
    create(:item, parent_item: @parent_item, status: :available)
    @parent_item.reload

    @parent_item.accessories.detect { |a| a.id == accessory.id }.name = "Changed Name"

    assert @parent_item.valid?
  end
end
