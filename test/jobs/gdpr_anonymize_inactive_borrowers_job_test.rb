# ABOUTME: Tests for GdprAnonymizeInactiveBorrowersJob.
# ABOUTME: Verifies queue assignment, anonymization behavior, and audit logging.

require "test_helper"

class GdprAnonymizeInactiveBorrowersJobTest < ActiveJob::TestCase
  test "job is queued to the low queue" do
    assert_enqueued_with(job: GdprAnonymizeInactiveBorrowersJob, queue: "low") do
      GdprAnonymizeInactiveBorrowersJob.perform_later
    end
  end

  test "job can be enqueued" do
    assert_enqueued_with(job: GdprAnonymizeInactiveBorrowersJob) do
      GdprAnonymizeInactiveBorrowersJob.perform_later
    end
  end

  test "perform creates audit logs with nil performed_by" do
    borrower = create(:borrower, :with_tos, updated_at: 25.months.ago)

    GdprAnonymizeInactiveBorrowersJob.perform_now

    log = GdprAuditLog.find_by(target: borrower, action: "anonymize")
    assert_not_nil log
    assert_nil log.performed_by
  end
end
