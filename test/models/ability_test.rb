# ABOUTME: Tests for CanCanCan authorization rules.
# ABOUTME: Covers admin, leader, member, guest, and cross-department scoping.

require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @other_department = create(:department)
  end

  # -- Admin --

  test "admin can manage everything" do
    user = create(:user, :admin, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:manage, User)
    assert ability.can?(:manage, Department)
    assert ability.can?(:manage, Borrower)
    assert ability.can?(:manage, ParentItem)
    assert ability.can?(:manage, Lending)
  end

  # -- Leader --

  test "leader can update own user" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:update, user)
  end

  test "leader can update non-admin users in same department" do
    leader = create(:user, :leader, department: @department)
    other_user = create(:user, department: @department)
    ability = Ability.new(leader)

    assert ability.can?(:update, other_user)
  end

  test "leader cannot update admin users" do
    leader = create(:user, :leader, department: @department)
    admin_user = create(:user, :admin, department: @department)
    ability = Ability.new(leader)

    assert ability.cannot?(:update, admin_user)
  end

  test "leader can manage borrowers" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:manage, Borrower)
  end

  test "leader can manage items in own department" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)
    parent_item = create(:parent_item, department: @department)
    other_item = create(:parent_item, department: @other_department)

    assert ability.can?(:manage, parent_item)
    assert ability.cannot?(:manage, other_item)
  end

  test "leader can manage lendings in own department" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)
    lending = create(:lending, user: user, department: @department)
    other_lending = create(:lending, department: @other_department)

    assert ability.can?(:manage, lending)
    assert ability.cannot?(:manage, other_lending)
  end

  test "leader can update own department" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:update, @department)
    assert ability.cannot?(:update, @other_department)
  end

  test "leader can staff and unstaff own department" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:staff, @department)
    assert ability.can?(:unstaff, @department)
    assert ability.cannot?(:staff, @other_department)
  end

  test "leader can read all" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:read, User)
    assert ability.can?(:read, Department)
    assert ability.can?(:read, Borrower)
  end

  # -- Member --

  test "member can manage items in own department" do
    user = create(:user, department: @department)
    ability = Ability.new(user)
    parent_item = create(:parent_item, department: @department)
    other_item = create(:parent_item, department: @other_department)

    assert ability.can?(:manage, parent_item)
    assert ability.cannot?(:manage, other_item)
  end

  test "member can update own user but not other users" do
    user = create(:user, department: @department)
    other_user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:update, user)
    assert ability.cannot?(:update, other_user)
  end

  test "member can manage borrowers" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:manage, Borrower)
  end

  test "member can staff and unstaff own department" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:staff, @department)
    assert ability.can?(:unstaff, @department)
  end

  # -- Guest --

  test "guest can read departments" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:read, Department)
  end

  test "guest can update own user" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:update, user)
  end

  test "guest cannot manage items" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, ParentItem)
    assert ability.cannot?(:update, create(:parent_item, department: @department))
    assert ability.cannot?(:destroy, create(:parent_item, department: @department))
  end

  test "guest cannot manage lendings" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, Lending)
  end

  test "guest can read borrowers and lendings" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:read, Borrower)
    assert ability.can?(:read, Lending)
    assert ability.can?(:read, ParentItem)
  end

  # -- Not logged in --

  test "unauthenticated user can only read departments" do
    ability = Ability.new(nil)

    assert ability.can?(:read, Department)
    assert ability.cannot?(:read, User)
    assert ability.cannot?(:read, Borrower)
    assert ability.cannot?(:manage, ParentItem)
  end
end
