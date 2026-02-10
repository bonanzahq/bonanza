# ABOUTME: Smoke test to verify User factory and department membership setup.
# ABOUTME: Tests that users are created with proper department associations.

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "factory creates a valid user with department membership" do
    user = create(:user)

    assert user.persisted?
    assert user.departments.any?, "User should have at least one department"
    assert user.current_department.present?, "User should have a current department"
    assert_equal "member", user.current_role
  end

  test "leader trait sets leader role" do
    user = create(:user, :leader)

    assert_equal "leader", user.current_role
  end

  test "admin trait sets admin flag" do
    user = create(:user, :admin)

    assert user.admin?
  end
end
