# ABOUTME: Tests for DepartmentsController staff/unstaff actions.
# ABOUTME: Verifies PATCH routes, authorization, and staffed state changes.
require "test_helper"

class DepartmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @member = create(:user, department: @department)
    @guest = create(:user, :guest, department: @department)
  end

  test "member can unstaff their department" do
    sign_in @member
    @department.update!(staffed: true)

    patch unstaff_department_path(@department)

    assert_redirected_to borrowers_path
    assert_not @department.reload.staffed, "Department should be unstaffed"
  end

  test "member can staff their department" do
    sign_in @member
    @department.update!(staffed: false)

    patch staff_department_path(@department)

    assert_redirected_to borrowers_path
    assert @department.reload.staffed, "Department should be staffed"
  end

  test "guest cannot unstaff department" do
    sign_in @guest
    @department.update!(staffed: true)

    patch unstaff_department_path(@department)

    assert_redirected_to root_path
    assert @department.reload.staffed, "Department should still be staffed"
  end

  test "guest cannot staff department" do
    sign_in @guest
    @department.update!(staffed: false)

    patch staff_department_path(@department)

    assert_redirected_to root_path
    assert_not @department.reload.staffed, "Department should still be unstaffed"
  end

  test "unstaff changes staffed from true to false" do
    sign_in @member
    @department.update!(staffed: true)

    assert_changes -> { @department.reload.staffed }, from: true, to: false do
      patch unstaff_department_path(@department)
    end
  end

  test "staff changes staffed from false to true" do
    sign_in @member
    @department.update!(staffed: false)

    assert_changes -> { @department.reload.staffed }, from: false, to: true do
      patch staff_department_path(@department)
    end
  end
end
