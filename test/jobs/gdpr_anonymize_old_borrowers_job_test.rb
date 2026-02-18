# ABOUTME: Tests for GdprAnonymizeOldBorrowersJob.
# ABOUTME: Verifies queue assignment and that the job can be enqueued.

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
end
