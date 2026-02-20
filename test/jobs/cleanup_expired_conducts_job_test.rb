# ABOUTME: Tests for CleanupExpiredConductsJob.
# ABOUTME: Verifies queue assignment and enqueuing.

require "test_helper"

class CleanupExpiredConductsJobTest < ActiveJob::TestCase
  test "uses low queue" do
    assert_equal "low", CleanupExpiredConductsJob.new.queue_name
  end

  test "can be enqueued" do
    assert_enqueued_with(job: CleanupExpiredConductsJob) do
      CleanupExpiredConductsJob.perform_later
    end
  end
end
