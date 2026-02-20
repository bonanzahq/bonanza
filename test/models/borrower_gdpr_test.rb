# ABOUTME: Tests for GDPR-related Borrower model methods.
# ABOUTME: Covers anonymize!, anonymized?, export_personal_data, request_deletion!, and audit logging.

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

  test "anonymize! creates an audit log entry" do
    @borrower.anonymize!(performed_by: @user)

    log = GdprAuditLog.last
    assert_equal "anonymize", log.action
    assert_equal @borrower, log.target
    assert_equal @user, log.performed_by
  end

  test "anonymize! creates audit log with nil performed_by for system actions" do
    @borrower.anonymize!

    log = GdprAuditLog.last
    assert_equal "anonymize", log.action
    assert_nil log.performed_by
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

  test "request_deletion! creates deletion_requested audit log" do
    result = @borrower.request_deletion!(performed_by: @user)

    log = GdprAuditLog.find_by(action: "deletion_requested")
    assert_not_nil log
    assert_equal @user, log.performed_by
  end

  test "request_deletion! creates both deletion_requested and anonymize audit logs when anonymizing" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_column(:returned_at, Time.current)

    assert_difference "GdprAuditLog.count", 2 do
      @borrower.request_deletion!(performed_by: @user)
    end

    actions = GdprAuditLog.where(target: @borrower).pluck(:action)
    assert_includes actions, "deletion_requested"
    assert_includes actions, "anonymize"
  end

  # -- gdpr_audit_logs association --

  test "borrower has gdpr_audit_logs association" do
    @borrower.anonymize!

    assert_equal 1, @borrower.gdpr_audit_logs.count
    assert_equal "anonymize", @borrower.gdpr_audit_logs.first.action
  end
end
