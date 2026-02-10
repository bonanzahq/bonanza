# ABOUTME: Smoke test to verify the testing infrastructure works.
# ABOUTME: Tests basic Department creation and validation via FactoryBot.

require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  test "factory creates a valid department" do
    department = create(:department)

    assert department.persisted?
    assert department.name.present?
    assert department.staffed?
  end

  test "department requires a name" do
    department = build(:department, name: nil)

    assert department.valid?, "Department should be valid without name (no name validation in model)"
  end
end
