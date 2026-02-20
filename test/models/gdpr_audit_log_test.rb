# ABOUTME: Tests for GdprAuditLog model validations and scopes.
# ABOUTME: Ensures audit log entries are correctly validated and queryable.

require "test_helper"

class GdprAuditLogTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    @borrower = create(:borrower, :with_tos)
  end

  # -- validations --

  test "valid with required attributes" do
    log = GdprAuditLog.new(action: "anonymize", target: @borrower)
    assert log.valid?
  end

  test "valid with performed_by" do
    log = GdprAuditLog.new(action: "anonymize", target: @borrower, performed_by: @user)
    assert log.valid?
  end

  test "invalid without action" do
    log = GdprAuditLog.new(target: @borrower)
    assert_not log.valid?
    assert log.errors[:action].any?
  end

  test "invalid with unknown action" do
    log = GdprAuditLog.new(action: "unknown", target: @borrower)
    assert_not log.valid?
    assert log.errors[:action].any?
  end

  test "invalid without target" do
    log = GdprAuditLog.new(action: "anonymize")
    assert_not log.valid?
    assert log.errors[:target].any?
  end

  test "accepts all defined actions" do
    GdprAuditLog::ACTIONS.each do |action|
      log = GdprAuditLog.new(action: action, target: @borrower)
      assert log.valid?, "Expected '#{action}' to be valid"
    end
  end

  test "stores metadata as JSON" do
    log = GdprAuditLog.create!(action: "export", target: @borrower, metadata: { format: "json" })
    log.reload
    assert_equal "json", log.metadata["format"]
  end

  # -- scopes --

  test "for_action returns logs matching the given action" do
    GdprAuditLog.create!(action: "anonymize", target: @borrower)
    GdprAuditLog.create!(action: "export", target: @borrower)

    results = GdprAuditLog.for_action("anonymize")
    assert_equal 1, results.count
    assert_equal "anonymize", results.first.action
  end

  test "for_target returns logs for the given target" do
    other_borrower = create(:borrower, :with_tos)
    GdprAuditLog.create!(action: "anonymize", target: @borrower)
    GdprAuditLog.create!(action: "anonymize", target: other_borrower)

    results = GdprAuditLog.for_target(@borrower)
    assert_equal 1, results.count
    assert_equal @borrower.id, results.first.target_id
  end

  # -- associations --

  test "target can be a Borrower" do
    log = GdprAuditLog.create!(action: "anonymize", target: @borrower)
    assert_equal "Borrower", log.target_type
    assert_equal @borrower, log.target
  end

  test "target can be a User" do
    log = GdprAuditLog.create!(action: "anonymize", target: @user)
    assert_equal "User", log.target_type
    assert_equal @user, log.target
  end

  test "performed_by can be nil for system actions" do
    log = GdprAuditLog.create!(action: "anonymize", target: @borrower, performed_by: nil)
    assert_nil log.performed_by
  end
end
