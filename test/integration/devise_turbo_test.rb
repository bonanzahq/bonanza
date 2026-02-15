# ABOUTME: Tests for Devise forms integration with Turbo.
# ABOUTME: Verifies that Turbo is disabled on forms that need full page reloads.

require "test_helper"

class DeviseTurboTest < ActionDispatch::IntegrationTest
  test "password reset request form has data-turbo=false" do
    get new_user_password_path
    assert_response :success
    assert_select 'form[data-turbo="false"]', count: 1
  end

