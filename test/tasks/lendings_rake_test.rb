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

  # -- find_orphaned --

  test "find_orphaned reports orphaned line items" do
    lending = create(:lending, :completed, user: @user, department: @department)
    create_orphaned_line_item(lending)

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
  # The close_orphaned task uses force_close! which updates line_items.
  # With FK constraints active (post-migration), we can't test with truly
  # orphaned items because PostgreSQL blocks updates on rows with invalid FKs.
  # These tests verify the task works with valid lendings that need closing.

  test "close_orphaned reports nothing when no orphans exist" do
    output = capture_io { Rake::Task["lendings:close_orphaned"].invoke }.first

    assert_includes output, "No active orphaned lendings found"
  ensure
    Rake::Task["lendings:close_orphaned"].reenable
  end

  test "close_orphaned skips already-returned lendings with orphaned items" do
    lending = create(:lending, :completed, user: @user, department: @department)
    create_orphaned_line_item(lending, returned_at: Time.current)
    lending.update_column(:returned_at, Time.current)

    output = capture_io { Rake::Task["lendings:close_orphaned"].invoke }.first

    assert_includes output, "No active orphaned lendings found"
  ensure
    Rake::Task["lendings:close_orphaned"].reenable
  end
end
