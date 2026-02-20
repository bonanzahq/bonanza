# ABOUTME: Tests for GDPR-related User model methods.
# ABOUTME: Covers anonymize!, anonymized?, and audit logging.

require "test_helper"

class UserGdprTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
  end

  # -- anonymize! --

  test "anonymize! replaces personal fields with placeholder values" do
    @user.anonymize!
    @user.reload

    assert_equal "Ehemaliger", @user.firstname
    assert_equal "Mitarbeiter", @user.lastname
    assert_match(/@anonymized\.local$/, @user.email)
    assert_equal "", @user.encrypted_password
  end

  test "anonymize! sets all department memberships to deleted role" do
    second_department = create(:department)
    @user.department_memberships.find_by(department: second_department).update!(role: :leader)

    @user.anonymize!

    @user.department_memberships.reload.each do |membership|
      assert_equal "deleted", membership.role
    end
  end

  # -- anonymized? --

  test "anonymized? returns false before anonymization" do
    assert_not @user.anonymized?
  end

  test "anonymized? returns true after anonymization" do
    @user.anonymize!

    assert @user.anonymized?
  end

  # -- audit logging --

  test "anonymize! creates an audit log entry" do
    other_user = create(:user, department: @department)
    @user.anonymize!(performed_by: other_user)

    log = GdprAuditLog.last
    assert_equal "anonymize", log.action
    assert_equal @user, log.target
    assert_equal other_user, log.performed_by
  end

  test "anonymize! creates audit log with nil performed_by for system actions" do
    @user.anonymize!

    log = GdprAuditLog.last
    assert_equal "anonymize", log.action
    assert_nil log.performed_by
  end

  test "user has gdpr_audit_logs association" do
    @user.anonymize!

    assert_equal 1, @user.gdpr_audit_logs.count
    assert_equal "anonymize", @user.gdpr_audit_logs.first.action
  end
end
