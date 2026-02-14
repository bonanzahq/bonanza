# ABOUTME: Tests for the ErrorHandling concern.
# ABOUTME: Verifies 404 and 500 error pages are rendered correctly.

require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    sign_in @user
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
    # Temporarily patch a controller method to raise
    original_method = BorrowersController.instance_method(:index)
    
    BorrowersController.class_eval do
      define_method(:index) { raise StandardError, "test explosion" }
    end

    Rails.application.config.consider_all_requests_local = false
    get borrowers_path
    assert_response :internal_server_error
  ensure
    Rails.application.config.consider_all_requests_local = true
    
    # Restore original method
    BorrowersController.class_eval do
      define_method(:index, original_method)
    end
  end

  test "renders internal_server_error template for 500" do
    # Temporarily patch a controller method to raise
    original_method = BorrowersController.instance_method(:index)
    
    BorrowersController.class_eval do
      define_method(:index) { raise StandardError, "test explosion" }
    end

    Rails.application.config.consider_all_requests_local = false
    get borrowers_path
    assert_select "h1", "Ein Fehler ist aufgetreten"
  ensure
    Rails.application.config.consider_all_requests_local = true
    
    # Restore original method
    BorrowersController.class_eval do
      define_method(:index, original_method)
    end
  end
end
