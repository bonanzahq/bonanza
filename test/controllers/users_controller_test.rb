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
end
