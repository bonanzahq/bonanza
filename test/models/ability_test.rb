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
    assert ability.cannot?(:unstaff, @other_department)
  end

  test "leader can read all" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:read, User)
    assert ability.can?(:read, Department)
    assert ability.can?(:read, Borrower)
  end

  test "leader cannot update users in other department" do
    leader = create(:user, :leader, department: @department)
    other_user = create(:user, department: @other_department)
    ability = Ability.new(leader)

    assert ability.cannot?(:update, other_user)
  end

  test "leader cannot create or destroy users" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, User)
    assert ability.cannot?(:destroy, User)
  end

  test "leader cannot create or destroy departments" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, Department)
    assert ability.cannot?(:destroy, Department)
  end

  test "leader can send_password_reset to same-department non-admin" do
    leader = create(:user, :leader, department: @department)
    member = create(:user, department: @department)
    ability = Ability.new(leader)

    assert ability.can?(:send_password_reset, member)
  end

  test "leader cannot send_password_reset to self" do
    leader = create(:user, :leader, department: @department)
    ability = Ability.new(leader)

    assert ability.cannot?(:send_password_reset, leader)
  end

  test "leader cannot send_password_reset to admin" do
    leader = create(:user, :leader, department: @department)
    admin_user = create(:user, :admin, department: @department)
    ability = Ability.new(leader)

    assert ability.cannot?(:send_password_reset, admin_user)
  end

  test "leader cannot send_password_reset to user in other department" do
    leader = create(:user, :leader, department: @department)
    other_user = create(:user, department: @other_department)
    ability = Ability.new(leader)

    assert ability.cannot?(:send_password_reset, other_user)
  end

  test "leader can edit and update checkout" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:edit, :checkout)
    assert ability.can?(:update, :checkout)
  end

  test "leader cannot create or destroy checkout" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, :checkout)
    assert ability.cannot?(:destroy, :checkout)
  end

  test "leader can take_back line_item in own department" do
    leader = create(:user, :leader, department: @department)
    ability = Ability.new(leader)
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    lending = create(:lending, user: leader, department: @department)
    line_item = create(:line_item, item: item, lending: lending)

    assert ability.can?(:take_back, line_item)
  end

  test "leader cannot take_back line_item in other department" do
    leader = create(:user, :leader, department: @department)
    other_leader = create(:user, :leader, department: @other_department)
    ability = Ability.new(leader)
    parent_item = create(:parent_item, department: @other_department)
    item = create(:item, parent_item: parent_item)
    lending = create(:lending, user: other_leader, department: @other_department)
    line_item = create(:line_item, item: item, lending: lending)

    assert ability.cannot?(:take_back, line_item)
  end

  test "leader can change_duration on lending in own department" do
    leader = create(:user, :leader, department: @department)
    ability = Ability.new(leader)
    lending = create(:lending, user: leader, department: @department)

    assert ability.can?(:change_duration, lending)
  end

  test "leader cannot change_duration on lending in other department" do
    leader = create(:user, :leader, department: @department)
    other_leader = create(:user, :leader, department: @other_department)
    ability = Ability.new(leader)
    other_lending = create(:lending, user: other_leader, department: @other_department)

    assert ability.cannot?(:change_duration, other_lending)
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
    assert ability.cannot?(:staff, @other_department)
    assert ability.cannot?(:unstaff, @other_department)
  end

  test "member can read all" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:read, User)
    assert ability.can?(:read, Department)
    assert ability.can?(:read, Borrower)
  end

  test "member cannot create or destroy users" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, User)
    assert ability.cannot?(:destroy, User)
  end

  test "member cannot send_password_reset" do
    user = create(:user, department: @department)
    other_user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:send_password_reset, other_user)
  end

  test "member can manage lendings in own department, not other" do
    user = create(:user, department: @department)
    ability = Ability.new(user)
    lending = create(:lending, user: user, department: @department)
    other_user = create(:user, department: @other_department)
    other_lending = create(:lending, user: other_user, department: @other_department)

    assert ability.can?(:manage, lending)
    assert ability.cannot?(:manage, other_lending)
  end

  test "member can edit and update checkout" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:edit, :checkout)
    assert ability.can?(:update, :checkout)
  end

  test "member can take_back line_item in own department" do
    user = create(:user, department: @department)
    ability = Ability.new(user)
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    lending = create(:lending, user: user, department: @department)
    line_item = create(:line_item, item: item, lending: lending)

    assert ability.can?(:take_back, line_item)
  end

  test "member cannot take_back line_item in other department" do
    user = create(:user, department: @department)
    other_user = create(:user, department: @other_department)
    ability = Ability.new(user)
    parent_item = create(:parent_item, department: @other_department)
    item = create(:item, parent_item: parent_item)
    lending = create(:lending, user: other_user, department: @other_department)
    line_item = create(:line_item, item: item, lending: lending)

    assert ability.cannot?(:take_back, line_item)
  end

  test "member can update own department but not other department" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:update, @department)
    assert ability.cannot?(:update, @other_department)
  end

  test "member cannot create or destroy department" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:create, Department)
    assert ability.cannot?(:destroy, @department)
  end

  test "member can change_duration on own-department lending" do
    user = create(:user, department: @department)
    ability = Ability.new(user)
    lending = create(:lending, user: user, department: @department)

    assert ability.can?(:change_duration, lending)
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

  test "guest cannot update other users" do
    user = create(:user, :guest, department: @department)
    other_user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:update, other_user)
  end

  test "guest cannot edit or update checkout" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:edit, :checkout)
    assert ability.cannot?(:update, :checkout)
  end

  test "guest cannot take_back line items" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    member = create(:user, department: @department)
    lending = create(:lending, user: member, department: @department)
    line_item = create(:line_item, item: item, lending: lending)

    assert ability.cannot?(:take_back, line_item)
  end

  test "guest cannot send_password_reset" do
    user = create(:user, :guest, department: @department)
    other_user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:send_password_reset, other_user)
  end

  test "guest cannot staff or unstaff department" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:staff, @department)
    assert ability.cannot?(:unstaff, @department)
  end

  test "guest cannot update department" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:update, @department)
  end

  test "guest cannot change_duration on lending" do
    user = create(:user, :guest, department: @department)
    member = create(:user, department: @department)
    ability = Ability.new(user)
    lending = create(:lending, user: member, department: @department)

    assert ability.cannot?(:change_duration, lending)
  end

  # -- Hidden (same permissions as member) --

  test "hidden user has member-level permissions" do
    user = create(:user, :hidden, department: @department)
    ability = Ability.new(user)
    parent_item = create(:parent_item, department: @department)
    other_item = create(:parent_item, department: @other_department)
    lending = create(:lending, user: user, department: @department)

    assert ability.can?(:read, :all)
    assert ability.can?(:update, user)
    assert ability.can?(:manage, Borrower)
    assert ability.can?(:manage, parent_item)
    assert ability.cannot?(:manage, other_item)
    assert ability.can?(:manage, lending)
    assert ability.can?(:edit, :checkout)
    assert ability.can?(:staff, @department)
    assert ability.can?(:unstaff, @department)
    assert ability.cannot?(:create, User)
    assert ability.cannot?(:destroy, User)
  end

  # -- Deleted --

  test "deleted user gets no permissions beyond reading departments" do
    user = create(:user, :deleted, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:read, Department)
    assert ability.cannot?(:update, user)
    assert ability.cannot?(:read, User)
    assert ability.cannot?(:read, Borrower)
    assert ability.cannot?(:manage, ParentItem)
    assert ability.cannot?(:manage, Lending)
  end

  # -- LegalText --

  test "admin can edit LegalText" do
    user = create(:user, :admin, department: @department)
    ability = Ability.new(user)

    assert ability.can?(:edit, LegalText)
  end

  test "leader cannot edit LegalText" do
    user = create(:user, :leader, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:edit, LegalText)
  end

  test "member cannot edit LegalText" do
    user = create(:user, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:edit, LegalText)
  end

  test "guest cannot edit LegalText" do
    user = create(:user, :guest, department: @department)
    ability = Ability.new(user)

    assert ability.cannot?(:edit, LegalText)
  end

  # -- Edge cases --

  test "user with no current_department gets no permissions beyond reading departments" do
    user = create(:user, department: @department)
    user.current_department = nil
    ability = Ability.new(user)

    assert ability.can?(:read, Department)
    assert ability.cannot?(:read, User)
    assert ability.cannot?(:read, Borrower)
    assert ability.cannot?(:manage, ParentItem)
    assert ability.cannot?(:manage, Lending)
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
