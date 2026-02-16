# ABOUTME: Tests for Department model business logic.
# ABOUTME: Covers staffed setter, visibility, genderize, membership callback, genus enum.

require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  # -- Factory --

  test "factory creates a valid department" do
    department = create(:department)

    assert department.persisted?
    assert department.name.present?
    assert department.staffed?
  end

  # -- Genus enum --

  test "genus enum has expected values" do
    expected = { "female" => 0, "male" => 1, "neuter" => 2 }
    assert_equal expected, Department.defined_enums["genus"]
  end

  # -- staffed= setter --

  test "setting staffed to true sets staffed_at timestamp" do
    department = Department.new(name: "Test")
    department.staffed = true

    assert department.staffed?
    assert department.staffed_at.present?
  end

  test "setting staffed to true again does not change staffed_at" do
    department = create(:department)
    original_staffed_at = department.staffed_at

    department.staffed = true

    assert_equal original_staffed_at.to_i, department.staffed_at.to_i
  end

  test "setting staffed to false clears staffed but not staffed_at" do
    department = create(:department)
    department.staffed = false

    assert_not department.staffed?
    assert department.staffed_at.present?
  end

  # -- get_all_visible_ids --

  test "get_all_visible_ids excludes hidden departments" do
    visible = create(:department, hidden: false)
    hidden = create(:department, hidden: true)

    ids = Department.get_all_visible_ids
    assert_includes ids, visible.id
    assert_not_includes ids, hidden.id
  end

  # -- genderize --

  test "genderize appends genus to key" do
    department = build(:department, genus: :female)
    assert_equal "item_female", department.genderize("item")

    department.genus = :male
    assert_equal "item_male", department.genderize("item")

    department.genus = :neuter
    assert_equal "item_neuter", department.genderize("item")
  end

  # -- create_memberships_for_all_users callback --

  test "rejects duplicate department names" do
    create(:department, name: "Werkstatt Holz")
    duplicate = build(:department, name: "Werkstatt Holz")

    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "new department auto-creates memberships for existing users" do
    user = create(:user)
    new_dept = create(:department)

    assert new_dept.users.reload.include?(user)
  end
end
