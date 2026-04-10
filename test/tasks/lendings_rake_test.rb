# ABOUTME: Tests for lendings rake tasks (find_orphaned, close_orphaned).
# ABOUTME: Verifies detection and automated cleanup of orphaned lendings.

require "test_helper"
require "rake"

class LendingsRakeTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    @admin = create(:user, :admin, department: @department)
    User.current_user = @user
    @parent_item = create(:parent_item, department: @department)

    Rails.application.load_tasks unless Rake::Task.task_defined?("lendings:find_orphaned")
  end

  private

  def hard_delete_items(*item_ids)
    ItemHistory.where(item_id: item_ids).delete_all
    Item.where(id: item_ids).delete_all
  end

  public

  # -- find_orphaned --

  test "find_orphaned reports orphaned line items" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)
    hard_delete_items(item.id)

    output = capture_io { Rake::Task["lendings:find_orphaned"].invoke }.first

    assert_includes output, "Found 1 orphaned line item(s)"
    assert_includes output, "Lending ##{lending.id}"
    assert_includes output, "MISSING"
  ensure
    Rake::Task["lendings:find_orphaned"].reenable
  end

  test "find_orphaned reports nothing when no orphans exist" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1)

    output = capture_io { Rake::Task["lendings:find_orphaned"].invoke }.first

    assert_includes output, "No orphaned line items found"
  ensure
    Rake::Task["lendings:find_orphaned"].reenable
  end

  # -- close_orphaned --

  test "close_orphaned force-closes active orphaned lendings" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    li = create(:line_item, lending: lending, item: item, quantity: 1)
    hard_delete_items(item.id)

    output = capture_io { Rake::Task["lendings:close_orphaned"].invoke }.first

    assert_includes output, "Closed lending ##{lending.id}"
    lending.reload
    assert lending.returned_at.present?
    li.reload
    assert li.returned_at.present?
  ensure
    Rake::Task["lendings:close_orphaned"].reenable
  end

  test "close_orphaned skips already-returned lendings" do
    item = create(:item, parent_item: @parent_item)
    lending = create(:lending, :completed, user: @user, department: @department)
    create(:line_item, lending: lending, item: item, quantity: 1, returned_at: Time.current)
    lending.update_column(:returned_at, Time.current)
    hard_delete_items(item.id)

    output = capture_io { Rake::Task["lendings:close_orphaned"].invoke }.first

    assert_includes output, "No active orphaned lendings found"
  ensure
    Rake::Task["lendings:close_orphaned"].reenable
  end

  test "close_orphaned reports nothing when no orphans exist" do
    output = capture_io { Rake::Task["lendings:close_orphaned"].invoke }.first

    assert_includes output, "No active orphaned lendings found"
  ensure
    Rake::Task["lendings:close_orphaned"].reenable
  end
end
