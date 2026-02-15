# ABOUTME: Tests for the ErrorHandling concern and exceptions_app routing.
# ABOUTME: Verifies 404 and 500 error pages are rendered correctly.

require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    sign_in @user
  end

  test "returns 404 for nonexistent route" do
    with_production_error_handling do
      get "/nonexistent-page"
      assert_response :not_found
      assert_select "h1", "Seite nicht gefunden"
    end
  end

  test "returns 404 for nonexistent borrower" do
    get borrower_path(id: 999_999)
    assert_response :not_found
  end

  test "renders not_found template for 404" do
    get borrower_path(id: 999_999)
    assert_select "h1", "Seite nicht gefunden"
  end

  test "handles StandardError and returns 500" do
    with_raised_index do
      with_production_error_handling do
        get borrowers_path
        assert_response :internal_server_error
      end
    end
  end

  test "renders internal_server_error template for 500" do
    with_raised_index do
      with_production_error_handling do
        get borrowers_path
        assert_select "h1", "Ein Fehler ist aufgetreten"
      end
    end
  end

  private

  def with_production_error_handling
    old_show = Rails.application.config.action_dispatch.show_exceptions
    old_detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    old_show_exceptions = Rails.application.env_config["action_dispatch.show_exceptions"]

    Rails.application.config.action_dispatch.show_exceptions = :rescuable
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    Rails.application.env_config["action_dispatch.show_exceptions"] = :rescuable
    yield
  ensure
    Rails.application.config.action_dispatch.show_exceptions = old_show
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = old_detailed
    Rails.application.env_config["action_dispatch.show_exceptions"] = old_show_exceptions
  end

  def with_raised_index
    original_method = BorrowersController.instance_method(:index)
    BorrowersController.class_eval do
      define_method(:index) { raise StandardError, "test explosion" }
    end
    yield
  ensure
    BorrowersController.class_eval do
      define_method(:index, original_method)
    end
  end
end
