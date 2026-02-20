# ABOUTME: Tests for GdprAnonymizeOldBorrowersJob.
# ABOUTME: Verifies queue assignment, anonymization behavior, and audit logging.

require "test_helper"

class GdprAnonymizeOldBorrowersJobTest < ActiveJob::TestCase
  test "job is queued to the low queue" do
    assert_enqueued_with(job: GdprAnonymizeOldBorrowersJob, queue: "low") do
      GdprAnonymizeOldBorrowersJob.perform_later
    end
  end

  test "job can be enqueued" do
    assert_enqueued_with(job: GdprAnonymizeOldBorrowersJob) do
      GdprAnonymizeOldBorrowersJob.perform_later
    end
  end

  test "perform creates audit logs with nil performed_by" do
    department = create(:department)
    user = create(:user, department: department)
    borrower = create(:borrower, :with_tos)
    lending = create(:lending, :completed, user: user, department: department, borrower: borrower)
    lending.update_columns(created_at: 8.years.ago, returned_at: 8.years.ago)

    GdprAnonymizeOldBorrowersJob.perform_now

    log = GdprAuditLog.find_by(target: borrower, action: "anonymize")
    assert_not_nil log
    assert_nil log.performed_by
  end
end
