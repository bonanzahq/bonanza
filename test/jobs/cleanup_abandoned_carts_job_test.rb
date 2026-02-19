# ABOUTME: Tests for CleanupAbandonedCartsJob.
# ABOUTME: Verifies queue assignment and enqueuing.

require "test_helper"

class CleanupAbandonedCartsJobTest < ActiveJob::TestCase
  test "uses low queue" do
    assert_equal "low", CleanupAbandonedCartsJob.new.queue_name
  end

  test "can be enqueued" do
    assert_enqueued_with(job: CleanupAbandonedCartsJob) do
      CleanupAbandonedCartsJob.perform_later
    end
  end
end
