# ABOUTME: Integration tests for UsersController.
# ABOUTME: Covers auth security: registration route disabled, password change restrictions.

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @admin = create(:user, :admin, department: @department)
    @leader = create(:user, :leader, department: @department)
    @member = create(:user, department: @department)
  end

  # -- Bug 1: Devise registration route should not exist --

  test "devise sign_up route does not exist" do
    assert_raises(ActionController::RoutingError) do
      get "/register/register"
    end
  end

  test "devise registration create route does not exist" do
    assert_raises(ActionController::RoutingError) do
      post "/register"
    end
  end

  # -- Bug 2: Password change restricted to self-edit --

  test "user can change their own password with correct current password" do
    sign_in @member
    new_password = "new-platypus-umbrella-cactus"
    patch user_path(@member), params: {
      user: { current_password: "platypus-umbrella-cactus", password: new_password, password_confirmation: new_password }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert @member.reload.valid_password?(new_password), "Password should have been updated"
  end

  test "user cannot change own password without providing current password" do
    sign_in @member
    original_password = @member.encrypted_password
    new_password = "new-platypus-umbrella-cactus"
    patch user_path(@member), params: {
      user: { password: new_password, password_confirmation: new_password }
    }
    assert_response :unprocessable_entity
    assert_equal original_password, @member.reload.encrypted_password,
      "Password should not change without current_password"
  end

  test "user cannot change own password with wrong current password" do
    sign_in @member
    original_password = @member.encrypted_password
    new_password = "new-platypus-umbrella-cactus"
    patch user_path(@member), params: {
      user: { current_password: "wrong-password-here", password: new_password, password_confirmation: new_password }
    }
    assert_response :unprocessable_entity
    assert_equal original_password, @member.reload.encrypted_password,
      "Password should not change with wrong current_password"
  end

  test "non-password profile updates do not require current password" do
    sign_in @member
    patch user_path(@member), params: {
      user: { firstname: "Updated" }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert_equal "Updated", @member.reload.firstname
  end

  test "admin cannot set another user's password" do
    sign_in @admin
    original_password = @member.encrypted_password
    patch user_path(@member), params: {
      user: { password: "hacked-password-12345", password_confirmation: "hacked-password-12345" }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert_equal original_password, @member.reload.encrypted_password,
      "Password should not have been changed by admin"
  end

  test "leader cannot set another user's password in same department" do
    sign_in @leader
    original_password = @member.encrypted_password
    patch user_path(@member), params: {
      user: { password: "hacked-password-12345", password_confirmation: "hacked-password-12345" }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert_equal original_password, @member.reload.encrypted_password,
      "Password should not have been changed by leader"
  end

  test "admin can trigger password reset for another user" do
    sign_in @admin
    post send_password_reset_user_path(@member)
    assert_redirected_to edit_user_path(@member)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "leader can trigger password reset for user in same department" do
    sign_in @leader
    post send_password_reset_user_path(@member)
    assert_redirected_to edit_user_path(@member)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "member cannot trigger password reset for another user" do
    sign_in @member
    post send_password_reset_user_path(@leader)
    assert_redirected_to root_path
  end

  # -- edit builds missing department memberships --

  test "edit form includes departments the user has no membership for" do
    # Create a second department that @member has no membership for
    new_dept = Department.create!(name: "New Dept")
    @member.department_memberships.find_by(department: new_dept)&.destroy

    assert_not @member.department_memberships.exists?(department: new_dept),
      "Precondition: member should not have a membership for the new department"

    sign_in @admin
    get edit_user_path(@member)
    assert_response :success
    assert_select "select[name*='department_memberships_attributes']" do |selects|
      dept_ids = selects.map { |s| s.parent.css("input[name*='department_id']").first&.attr("value")&.to_i }
      assert_includes dept_ids, new_dept.id,
        "Edit form should include a role select for the new department"
    end
  end

  test "admin can assign role in a new department via edit form" do
    new_dept = Department.create!(name: "New Dept")
    @member.department_memberships.find_by(department: new_dept)&.destroy

    sign_in @admin
    # First get the edit form to build the membership
    get edit_user_path(@member)

    # Submit with the new department role set to leader
    existing_memberships = @member.department_memberships.reload.map do |dm|
      { id: dm.id, role: dm.role, department_id: dm.department_id }
    end

    attrs = {}
    existing_memberships.each_with_index do |dm, i|
      attrs[i.to_s] = { id: dm[:id], role: dm[:role], department_id: dm[:department_id] }
    end
    attrs[existing_memberships.size.to_s] = { role: "leader", department_id: new_dept.id }

    patch user_path(@member), params: {
      user: { department_memberships_attributes: attrs }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert @member.reload.department_memberships.exists?(department: new_dept, role: :leader),
      "Member should now have a leader membership in the new department"
  end

  # -- switch_department --

  test "authenticated multi-department user can switch to another department" do
    # Department before_create callback auto-adds all existing users to the new dept
    other_dept = create(:department)
    original_dept_id = @member.current_department_id

    sign_in @member
    patch switch_department_path, params: { department_id: other_dept.id }

    assert_redirected_to root_path
    assert_not_equal original_dept_id, @member.reload.current_department_id
    assert_equal other_dept.id, @member.current_department_id
  end

  test "current_department_id is persisted in DB after department switch" do
    other_dept = create(:department)

    sign_in @member
    patch switch_department_path, params: { department_id: other_dept.id }

    assert_equal other_dept.id, @member.reload.current_department_id
  end

  test "cannot switch to department user does not belong to" do
    other_dept = create(:department)
    # @member was auto-added by before_create; destroy that membership
    @member.department_memberships.find_by(department: other_dept).destroy
    original_dept_id = @member.current_department_id

    sign_in @member
    patch switch_department_path, params: { department_id: other_dept.id }

    assert_response :redirect
    assert_equal original_dept_id, @member.reload.current_department_id
  end

  test "cannot switch to department where membership is deleted" do
    other_dept = create(:department)
    @member.department_memberships.find_by(department: other_dept).update!(role: :deleted)
    original_dept_id = @member.current_department_id

    sign_in @member
    patch switch_department_path, params: { department_id: other_dept.id }

    assert_response :redirect
    assert_equal original_dept_id, @member.reload.current_department_id
  end

  test "unauthenticated user is redirected to login when switching department" do
    other_dept = create(:department)

    patch switch_department_path, params: { department_id: other_dept.id }

    assert_redirected_to new_user_session_path
  end

  # -- strong parameters --

  test "update ignores unpermitted params" do
    sign_in @admin
    original_password = @member.encrypted_password
    patch user_path(@member), params: {
      user: { firstname: "Updated", evil_field: "hacked" }
    }
    assert_redirected_to verwaltung_verleihende_path
    assert_equal "Updated", @member.reload.firstname
    assert_equal original_password, @member.reload.encrypted_password
  end
end
