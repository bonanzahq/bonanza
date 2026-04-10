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

  # Inserts a line item referencing a non-existent item by temporarily disabling
  # FK triggers. Used to simulate orphaned state from v1 migration.
  def create_orphaned_line_item(lending, quantity: 1, returned_at: nil)
    fake_item_id = 999_999_000 + rand(1000)
    returned_sql = returned_at ? "'#{returned_at.utc.iso8601}'" : "NULL"
    now = Time.current.utc.iso8601

    ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica'")
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO line_items (item_id, lending_id, quantity, returned_at, created_at, updated_at)
      VALUES (#{fake_item_id}, #{lending.id}, #{quantity}, #{returned_sql}, '#{now}', '#{now}')
    SQL
    ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin'")

    LineItem.where(lending_id: lending.id, item_id: fake_item_id).first!
  end

  public

  # -- LineItem.orphaned scope --

  test "orphaned scope returns line items referencing non-existent items" do
    lending = create(:lending, :completed, user: @user, department: @department)
    orphaned_li = create_orphaned_line_item(lending)

    assert_includes LineItem.orphaned, orphaned_li
  end

  test "orphaned scope excludes line items with existing items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    line_item = create(:line_item, lending: lending, item: item, quantity: 1)

    assert_not_includes LineItem.orphaned, line_item
  end

  # -- Lending.with_orphaned_items scope --

  test "with_orphaned_items returns lendings that have orphaned line items" do
    lending = create(:lending, :completed, user: @user, department: @department)
    create_orphaned_line_item(lending)

    assert_includes Lending.with_orphaned_items, lending
  end

  test "with_orphaned_items excludes lendings with valid items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    assert_not_includes Lending.with_orphaned_items, lending
  end

  # -- force_close! with valid items --

  test "force_close sets returned_at on lending" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    lending.force_close!(@admin, "Admin override")

    lending.reload
    assert lending.returned_at.present?
  end

  test "force_close sets returned_at on all unreturned line items" do
    item1 = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    item2 = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    li1 = create(:line_item, lending: lending, item: item1, quantity: 1)
    li2 = create(:line_item, lending: lending, item: item2, quantity: 1)

    lending.force_close!(@admin, "Cleanup")

    li1.reload
    li2.reload
    assert li1.returned_at.present?
    assert li2.returned_at.present?
  end

  test "force_close does not overwrite already-returned line items" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    original_time = 3.days.ago
    li = create(:line_item, lending: lending, item: item, quantity: 1, returned_at: original_time)

    lending.force_close!(@admin, "Cleanup")

    li.reload
    assert_in_delta original_time, li.returned_at, 1.second
  end

  test "force_close records reason and user in note" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    lending.force_close!(@admin, "Items deleted during v1 migration")

    lending.reload
    assert_includes lending.note, "Items deleted during v1 migration"
    assert_includes lending.note, @admin.email
    assert_includes lending.note, "Force-closed by"
  end

  test "force_close appends to existing note" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_column(:note, "Original note")
    create(:line_item, lending: lending, item: item, quantity: 1)

    lending.force_close!(@admin, "Override reason")

    lending.reload
    assert_includes lending.note, "Original note"
    assert_includes lending.note, "Override reason"
  end

  test "force_close restores item quantity and sets available" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 3)

    lending.force_close!(@admin, "Force closing")

    item.reload
    assert_equal 3, item.quantity
    assert_equal "available", item.status
  end

  test "force_close raises on already-returned lending" do
    lending = create(:lending, :completed, user: @user, department: @department)
    lending.update_column(:returned_at, Time.current)

    assert_raises(RuntimeError) do
      lending.force_close!(@admin, "Should fail")
    end
  end

  test "force_close requires a reason" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    assert_raises(ArgumentError) do
      lending.force_close!(@admin, "")
    end
  end

  test "force_close with nil reason raises" do
    item = create(:item, parent_item: @parent_item, quantity: 0, status: :lent)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    assert_raises(ArgumentError) do
      lending.force_close!(@admin, nil)
    end
  end
end
