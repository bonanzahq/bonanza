# ABOUTME: Tests for GDPR-related Borrower model methods.
# ABOUTME: Covers anonymize!, anonymized?, export_personal_data, and request_deletion!.

require "test_helper"

class BorrowerGdprTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    @borrower = create(:borrower, :with_tos)
  end

  # -- anonymize! --

  test "anonymize! replaces personal fields with placeholder values" do
    @borrower.anonymize!
    @borrower.reload

    assert_equal "Geloescht", @borrower.firstname
    assert_equal "Person", @borrower.lastname
    assert_match(/@anonymized\.local$/, @borrower.email)
    assert_equal "000000", @borrower.phone
    assert_nil @borrower.student_id
    assert_nil @borrower.email_token
    assert @borrower.deleted?
  end

  test "anonymize! sets borrower_type to deleted" do
    @borrower.anonymize!

    assert @borrower.reload.deleted?
  end

  # -- anonymized? --

  test "anonymized? returns false before anonymization" do
    assert_not @borrower.anonymized?
  end

  test "anonymized? returns true after anonymization" do
    @borrower.anonymize!

    assert @borrower.anonymized?
  end

  # -- export_personal_data --

  test "export_personal_data includes personal information" do
    data = @borrower.export_personal_data

    assert_equal @borrower.id, data[:personal_information][:id]
    assert_equal @borrower.firstname, data[:personal_information][:firstname]
    assert_equal @borrower.lastname, data[:personal_information][:lastname]
    assert_equal @borrower.email, data[:personal_information][:email]
    assert_equal @borrower.phone, data[:personal_information][:phone]
    assert_equal @borrower.student_id, data[:personal_information][:student_id]
    assert_equal @borrower.borrower_type, data[:personal_information][:type]
  end

  test "export_personal_data includes lendings" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)

    data = @borrower.export_personal_data

    assert_equal 1, data[:lendings].length
    lending_data = data[:lendings].first
    assert_equal lending.id, lending_data[:id]
    assert_equal @department.name, lending_data[:department]
    assert_kind_of Array, lending_data[:items]
  end

  test "export_personal_data includes conducts" do
    create(:conduct, borrower: @borrower, department: @department, user: @user, permanent: true)

    data = @borrower.export_personal_data

    assert_equal 1, data[:conducts].length
    conduct_data = data[:conducts].first
    assert_equal @department.name, conduct_data[:department]
    assert conduct_data.key?(:type)
    assert conduct_data.key?(:reason)
    assert conduct_data.key?(:permanent)
  end

  test "export_personal_data includes exported_at timestamp" do
    data = @borrower.export_personal_data

    assert data[:exported_at].present?
  end

  # -- request_deletion! --

  test "request_deletion! raises error when borrower has active lendings" do
    create(:lending, :completed, user: @user, department: @department, borrower: @borrower)

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @borrower.request_deletion!
    end
  end

  test "request_deletion! anonymizes borrower with recent lending history" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_column(:returned_at, Time.current)

    result = @borrower.request_deletion!

    assert_equal :anonymized, result
    assert @borrower.reload.anonymized?
  end

  test "request_deletion! destroys borrower when no lendings exist" do
    result = @borrower.request_deletion!

    assert_equal :deleted, result
    assert_not Borrower.exists?(@borrower.id)
  end

  test "request_deletion! destroys borrower when all lendings are older than 7 years" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_columns(created_at: 8.years.ago, returned_at: 8.years.ago)

    result = @borrower.request_deletion!

    assert_equal :deleted, result
    assert_not Borrower.exists?(@borrower.id)
  end
end
