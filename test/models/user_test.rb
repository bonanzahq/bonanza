# ABOUTME: Tests for User model business logic.
# ABOUTME: Covers validations, roles, department memberships, fullname, current_user.

require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
  end

  # -- Factory smoke tests --

  test "factory creates a valid user with department membership" do
    assert @user.persisted?
    assert @user.departments.any?
    assert @user.current_department.present?
    assert_equal "member", @user.current_role
  end

  test "leader trait sets leader role" do
    user = create(:user, :leader)
    assert_equal "leader", user.current_role
  end

  test "admin trait sets admin flag" do
    user = create(:user, :admin)
    assert user.admin?
  end

  # -- Validations --

  test "requires firstname" do
    @user.firstname = nil
    assert_not @user.valid?
  end

  test "requires lastname" do
    @user.lastname = nil
    assert_not @user.valid?
  end

  test "requires department_memberships" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      firstname: "Test",
      lastname: "User"
    )
    assert_not user.valid?
    assert user.errors[:department_memberships].any?
  end

  test "email must be unique" do
    duplicate = build(:user, email: @user.email)
    assert_not duplicate.valid?
  end

  # -- Fullname --

  test "fullname concatenates first and last name" do
    @user.firstname = "Max"
    @user.lastname = "Mustermann"
    assert_equal "Max Mustermann", @user.fullname
  end

  # -- Role queries --
  # TODO verify that all the other flags are false?

  test "guest? returns true for guest role" do
    user = create(:user, :guest)
    assert user.guest?
  end

  test "member? returns true for member role" do
    assert @user.member?
  end

  test "leader? returns true for leader role" do
    user = create(:user, :leader)
    assert user.leader?
  end

  test "admin? returns true when admin flag is set" do
    assert_not @user.admin?
    @user.admin = true
    assert @user.admin?
  end

  # -- current_role --

  test "current_role returns role for current department" do
    assert_equal "member", @user.current_role
  end

  # TODO: create an issue for the problem below
  # NOTE: current_role= setter has a design issue: find_or_initialize_by returns
  # a transient DB object, sets role on it, then discards it. The change is never
  # persisted or retained in the association cache. Needs investigation.

  # -- role_in --

  test "role_in returns role for a specific department" do
    other_dept = create(:department)
    # Department's before_create callback auto-creates memberships for all users,
    # so update the existing one instead of creating a duplicate.
    @user.department_memberships.find_by(department: other_dept).update!(role: :leader)

    assert_equal "member", @user.role_in(@department)
    assert_equal "leader", @user.role_in(other_dept)
  end

  # -- is_guest_everywhere? --

  test "is_guest_everywhere? returns true when all roles are guest" do
    @user.department_memberships.update_all(role: DepartmentMembership.roles[:guest])
    assert @user.is_guest_everywhere?
  end

  test "is_guest_everywhere? returns false with non-guest role" do
    assert_not @user.is_guest_everywhere?
  end

  test "is_guest_everywhere? ignores deleted memberships" do
    @user.department_memberships.update_all(role: DepartmentMembership.roles[:deleted])
    assert @user.is_guest_everywhere?
  end

  # -- ensure_current_department --

  test "ensure_current_department sets department if nil" do
    @user.current_department = nil
    @user.valid?

    assert @user.current_department.present?
  end

  # -- Thread-local current_user --

  test "current_user is thread-local" do
    User.current_user = @user
    assert_equal @user, User.current_user

    User.current_user = nil
    assert_nil User.current_user
  end
end
