# ABOUTME: Tests for GdprCleanupOldConductsJob.
# ABOUTME: Verifies queue assignment and that the job can be enqueued.

require "test_helper"

class GdprCleanupOldConductsJobTest < ActiveJob::TestCase
  test "job is queued to the low queue" do
    assert_enqueued_with(job: GdprCleanupOldConductsJob, queue: "low") do
      GdprCleanupOldConductsJob.perform_later
    end
  end

  test "job can be enqueued" do
    assert_enqueued_with(job: GdprCleanupOldConductsJob) do
      GdprCleanupOldConductsJob.perform_later
    end
  end
end
