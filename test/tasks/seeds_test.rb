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

  test "seeds create users for all department roles" do
    assert_difference "User.count", 5 do
      load Rails.root.join("db/seeds.rb")
    end

    admin = User.find_by!(email: "admin@example.com")
    assert admin.admin, "admin@example.com should have admin=true"
    assert_equal "leader", admin.current_role

    leader = User.find_by!(email: "leader@example.com")
    assert_not leader.admin, "leader@example.com should have admin=false"
    assert_equal "leader", leader.current_role

    member = User.find_by!(email: "member@example.com")
    assert_not member.admin, "member@example.com should have admin=false"
    assert_equal "member", member.current_role

    guest = User.find_by!(email: "guest@example.com")
    assert_not guest.admin, "guest@example.com should have admin=false"
    assert_equal "guest", guest.current_role

    hidden = User.find_by!(email: "hidden@example.com")
    assert_not hidden.admin, "hidden@example.com should have admin=false"
    assert_equal "hidden", hidden.current_role
  end
end
