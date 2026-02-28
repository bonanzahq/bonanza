# ABOUTME: Tests for DepartmentsController actions including staff/unstaff,
# ABOUTME: dual-purpose index (management vs public), and show views.
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

    assert_redirected_to public_home_page_path
    assert @department.reload.staffed, "Department should still be staffed"
  end

  test "guest cannot staff department" do
    sign_in @guest
    @department.update!(staffed: false)

    patch staff_department_path(@department)

    assert_redirected_to public_home_page_path
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

  # --- Management index tests ---

  test "admin sees management departments index" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get departments_path
    assert_response :success
    assert_select "header .bnz-tab-navigation h4", "Werkstätten"
    assert_select "a.link-back", text: "Verwaltung"
  end

  test "leader sees management departments index" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get departments_path
    assert_response :success
    assert_select "header .bnz-tab-navigation h4", "Werkstätten"
    assert_select "a.link-back", text: "Verwaltung"
  end

  test "member sees management departments index" do
    sign_in @member

    get departments_path
    assert_response :success
    assert_select "header .bnz-tab-navigation h4", "Werkstätten"
    assert_select "a.link-back", text: "Verwaltung"
  end

  test "unauthenticated user sees public departments index" do
    get departments_path
    assert_response :success
    assert_select ".justify-content-center h3", "Werkstätten"
  end

  test "management index lists all departments including hidden for admin" do
    admin = create(:user, :admin, department: @department)
    hidden_dept = create(:department, hidden: true)
    sign_in admin

    get departments_path
    assert_response :success
    assert_select ".bg-light h3 a", @department.name
    assert_select ".bg-light h3 a", hidden_dept.name
  end

  test "management index shows department details" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get departments_path
    assert_response :success
    assert_select ".bg-light h3 a", text: /#{@department.name}/
    assert_select ".bnz-card", text: /#{@department.room}/
  end

  test "admin sees new department link in management index" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get departments_path
    assert_response :success
    assert_select "a[href='#{new_department_path}']"
  end

  test "admin can render new department page" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get new_department_path
    assert_response :success
    assert_select "a[href='#{departments_path}']", text: "Abbrechen"
  end

  test "leader does not see new department link in management index" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get departments_path
    assert_response :success
    assert_select "a[href='#{new_department_path}']", false
  end

  # --- Show view tests ---

  test "admin sees management department show" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get department_path(@department)
    assert_response :success
    assert_select "header .bnz-tab-navigation h4", "Werkstatt"
    assert_select "h3", @department.name
  end

  test "leader sees management department show" do
    leader = create(:user, :leader, department: @department)
    sign_in leader

    get department_path(@department)
    assert_response :success
    assert_select "header .bnz-tab-navigation h4", "Werkstatt"
  end

  test "admin sees edit link on department show" do
    admin = create(:user, :admin, department: @department)
    sign_in admin

    get department_path(@department)
    assert_response :success
    assert_select "a[href='#{edit_department_path(@department)}']"
  end

  test "member sees management department show" do
    sign_in @member

    get department_path(@department)
    assert_response :success
    assert_select "h3", @department.name
  end

  test "guest is redirected from department show to index" do
    guest = create(:user, :guest, department: @department)
    sign_in guest

    get department_path(@department)
    assert_redirected_to departments_path
  end

  test "member does not see edit link on management index" do
    sign_in @member

    get departments_path
    assert_response :success
    assert_select "a[href='#{edit_department_path(@department)}']", false
  end

  test "member does not see new department link on management index" do
    sign_in @member

    get departments_path
    assert_response :success
    assert_select "a[href='#{new_department_path}']", false
  end

  test "member does not see edit link on department show" do
    sign_in @member

    get department_path(@department)
    assert_response :success
    assert_select "a[href='#{edit_department_path(@department)}']", false
  end

  test "member sees staff button on department show" do
    sign_in @member
    @department.update!(staffed: true)

    get department_path(@department)
    assert_response :success
    assert_select "a[href='#{unstaff_department_path(@department)}']"
  end

  test "department show displays all details" do
    admin = create(:user, :admin, department: @department)
    @department.update!(time: "Mo-Fr 10-16", note: "Testwerkstatt", default_lending_duration: 7)
    sign_in admin

    get department_path(@department)
    assert_response :success
    assert_select ".bnz-card", text: /#{@department.room}/
    assert_select ".bnz-card", text: /Mo-Fr 10-16/
    assert_select ".bnz-card", text: /7/
  end

  test "member cannot update department" do
    sign_in @member

    patch department_path(@department), params: { department: { name: "Hacked" } }

    assert_redirected_to root_path
    assert_not_equal "Hacked", @department.reload.name
  end

  test "guest cannot update department" do
    sign_in @guest

    patch department_path(@department), params: { department: { name: "Hacked" } }

    assert_redirected_to public_home_page_path
    assert_not_equal "Hacked", @department.reload.name
  end
end
