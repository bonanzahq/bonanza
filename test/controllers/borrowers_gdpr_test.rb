# ABOUTME: Integration tests for GDPR actions on BorrowersController.
# ABOUTME: Covers data export and deletion request endpoints.

require "test_helper"

class BorrowersGdprTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    User.current_user = @user
    @borrower = create(:borrower, :with_tos, insurance_checked: true, id_checked: true)
  end

  test "export_data requires authentication" do
    get export_data_borrower_path(@borrower)
    assert_redirected_to new_user_session_path
  end

  test "export_data returns JSON file" do
    sign_in @user
    get export_data_borrower_path(@borrower)
    assert_response :success
    assert_equal "application/json", response.content_type
  end

  test "request_deletion requires authentication" do
    post request_deletion_borrower_path(@borrower)
    assert_redirected_to new_user_session_path
  end

  test "request_deletion anonymizes borrower without active lendings" do
    sign_in @user
    # Borrower has a returned lending (returned_at set), so request_deletion! anonymizes
    # rather than fully deletes (recent lending history within 7 years is retained via anonymization)
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_column(:returned_at, Time.current)
    post request_deletion_borrower_path(@borrower)
    assert_redirected_to borrowers_url
    @borrower.reload
    assert @borrower.anonymized?
  end

  test "request_deletion fails for borrower with active lending" do
    sign_in @user
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    create(:line_item, lending: lending)
    post request_deletion_borrower_path(@borrower)
    assert_redirected_to borrower_path(@borrower)
    @borrower.reload
    refute @borrower.anonymized?
  end

  test "request_deletion shows error flash when borrower has active lendings" do
    sign_in @user
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    create(:line_item, lending: lending)
    post request_deletion_borrower_path(@borrower)
    assert_equal "Löschung nicht möglich: Offene Ausleihen vorhanden", flash[:alert]
  end
end
