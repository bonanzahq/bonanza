# ABOUTME: Tests for Devise forms integration with Turbo.
# ABOUTME: Verifies that Turbo is disabled on forms that need full page reloads.

require "test_helper"

class DeviseTurboTest < ActionDispatch::IntegrationTest
  test "password reset request form has data-turbo=false" do
    get new_user_password_path
    assert_response :success
    assert_select 'form[data-turbo="false"]', count: 1
  end

  test "password edit form has data-turbo=false and German text" do
    department = Department.create!(name: "Test Department")
    user = User.new(
      email: "test@example.com",
      password: "password",
      password_confirmation: "password",
      firstname: "Test",
      lastname: "User"
    )
    user.department_memberships.build(department: department, role: :leader)
    user.save!
    
    raw_token = user.send_reset_password_instructions
    
    get edit_user_password_path(reset_password_token: raw_token)
    assert_response :success
    
    # Check form has data-turbo=false
    assert_select 'form[data-turbo="false"]', count: 1
    
    # Check German text
    assert_select 'h3', text: 'Neues Passwort festlegen'
    
    # Check Bootstrap classes are present
    assert_select 'input.form-control[type="password"]'
  end

  test "registration form has data-turbo=false and German text" do
    get new_user_registration_path
    assert_response :success
    
    # Check form has data-turbo=false
    assert_select 'form[data-turbo="false"]', count: 1
    
    # Check German text
    assert_select 'h3', text: 'Registrieren'
    
    # Check Bootstrap classes are present
    assert_select 'input.form-control'
  end

  test "profile edit form has data-turbo=false and German text" do
    department = Department.create!(name: "Test Department")
    user = User.new(
      email: "test@example.com",
      password: "password",
      password_confirmation: "password",
      firstname: "Test",
      lastname: "User"
    )
    user.department_memberships.build(department: department, role: :leader)
    user.current_department = department
    user.save!
    
    sign_in user
    
    get edit_user_registration_path
    assert_response :success
    
    # Check profile edit form has data-turbo=false
    assert_select 'form[data-turbo="false"]', count: 1
    
    # Check German text
    assert_select 'h3', text: 'Profil bearbeiten'
    
    # Check Bootstrap classes are present
    assert_select 'input.form-control'
  end
end
