# ABOUTME: Tests that db/seeds.rb only runs in non-production environments.
# ABOUTME: Prevents hardcoded dev credentials from being created in production.

require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds do not execute in production environment" do
    Rails.env = "production"

    initial_user_count = User.count
    initial_department_count = Department.count
    initial_parent_item_count = ParentItem.count

    load Rails.root.join("db/seeds.rb")

    assert_equal initial_user_count, User.count, "Seeds should not create users in production"
    assert_equal initial_department_count, Department.count, "Seeds should not create departments in production"
    assert_equal initial_parent_item_count, ParentItem.count, "Seeds should not create items in production"
  ensure
    Rails.env = "test"
  end
end
