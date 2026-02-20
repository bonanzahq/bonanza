# ABOUTME: Tests for GdprAnonymizeInactiveBorrowersJob.
# ABOUTME: Verifies queue assignment and that the job can be enqueued.

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
end
