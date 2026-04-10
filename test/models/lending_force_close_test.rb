# ABOUTME: Tests for Lending#force_close! and orphaned lending detection.
# ABOUTME: Covers force-closing lendings with orphaned or valid line items.

require "test_helper"

class LendingForceCloseTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    @admin = create(:user, :admin, department: @department)
    User.current_user = @user
    @parent_item = create(:parent_item, department: @department)
  end

  private

  # Hard-deletes an item and its history records to simulate orphaned state.
  # In production, orphans were created by v1 migration deleting items without
  # cleaning up line_items. The FK on item_histories requires us to delete
  # history first in tests.
  def hard_delete_items(*item_ids)
    ItemHistory.where(item_id: item_ids).delete_all
    Item.where(id: item_ids).delete_all
  end

  public

  # -- LineItem.orphaned scope --

  test "orphaned scope returns line items referencing non-existent items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    line_item = create(:line_item, lending: lending, item: item, quantity: 1)

    # Hard-delete the item, bypassing callbacks and the soft-delete override
    hard_delete_items(item.id)

    assert_includes LineItem.orphaned, line_item
  end

  test "orphaned scope excludes line items with existing items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    line_item = create(:line_item, lending: lending, item: item, quantity: 1)

    assert_not_includes LineItem.orphaned, line_item
  end

  # -- Lending.with_orphaned_items scope --

  test "with_orphaned_items returns lendings that have orphaned line items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    hard_delete_items(item.id)

    assert_includes Lending.with_orphaned_items, lending
  end

  test "with_orphaned_items excludes lendings with valid items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    assert_not_includes Lending.with_orphaned_items, lending
  end

  # -- force_close! --

  test "force_close sets returned_at on lending" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)
    hard_delete_items(item.id)

    lending.force_close!(@admin, "Orphaned items from v1 migration")

    lending.reload
    assert lending.returned_at.present?
  end

  test "force_close sets returned_at on all unreturned line items" do
    item1 = create(:item, parent_item: @parent_item)
    item2 = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    li1 = create(:line_item, lending: lending, item: item1, quantity: 1)
    li2 = create(:line_item, lending: lending, item: item2, quantity: 1)

    hard_delete_items(item1.id, item2.id)

    lending.force_close!(@admin, "Cleanup")

    li1.reload
    li2.reload
    assert li1.returned_at.present?
    assert li2.returned_at.present?
  end

  test "force_close does not overwrite already-returned line items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    original_time = 3.days.ago
    li = create(:line_item, lending: lending, item: item, quantity: 1, returned_at: original_time)
    hard_delete_items(item.id)

    lending.force_close!(@admin, "Cleanup")

    li.reload
    assert_in_delta original_time, li.returned_at, 1.second
  end

  test "force_close records reason in note" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)
    hard_delete_items(item.id)

    lending.force_close!(@admin, "Items deleted during v1 migration")

    lending.reload
    assert_includes lending.note, "Items deleted during v1 migration"
    assert_includes lending.note, @admin.email
  end

  test "force_close restores item quantity for non-orphaned line items" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    lending.force_close!(@admin, "Force closing")

    item.reload
    assert_equal 1, item.quantity
    assert_equal "available", item.status
  end

  test "force_close handles mix of orphaned and valid line items" do
    orphaned_item = create(:item, parent_item: @parent_item)
    valid_item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    li_orphaned = create(:line_item, lending: lending, item: orphaned_item, quantity: 1)
    li_valid = create(:line_item, lending: lending, item: valid_item, quantity: 1)

    hard_delete_items(orphaned_item.id)

    lending.force_close!(@admin, "Mixed cleanup")

    li_orphaned.reload
    li_valid.reload
    valid_item.reload

    assert li_orphaned.returned_at.present?
    assert li_valid.returned_at.present?
    assert_equal 1, valid_item.quantity
    assert_equal "available", valid_item.status
    assert lending.reload.returned_at.present?
  end

  test "force_close raises on already-returned lending" do
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_column(:returned_at, Time.current)

    assert_raises(RuntimeError) do
      lending.force_close!(@admin, "Should fail")
    end
  end

  test "force_close requires a reason" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)
    hard_delete_items(item.id)

    assert_raises(ArgumentError) do
      lending.force_close!(@admin, "")
    end
  end
end
