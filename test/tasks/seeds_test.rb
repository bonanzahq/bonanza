# ABOUTME: Tests that db/seeds.rb only runs in non-production environments.
# ABOUTME: Prevents hardcoded dev credentials from being created in production.

require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds do not execute in production environment" do
    original_env = Rails.env
    Rails.env = "production"

    assert_no_difference "User.count", "Seeds should not create users in production" do
      assert_no_difference "Department.count", "Seeds should not create departments in production" do
        assert_no_difference "ParentItem.count", "Seeds should not create items in production" do
          load Rails.root.join("db/seeds.rb")
        end
      end
    end
  ensure
    Rails.env = original_env
  end
end
