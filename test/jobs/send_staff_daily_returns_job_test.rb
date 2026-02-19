# ABOUTME: Tests for SendStaffDailyReturnsJob.
# ABOUTME: Verifies queue assignment and enqueuing.

require "test_helper"

class SendStaffDailyReturnsJobTest < ActiveJob::TestCase
  test "uses low queue" do
    assert_equal "low", SendStaffDailyReturnsJob.new.queue_name
  end

  test "can be enqueued" do
    assert_enqueued_with(job: SendStaffDailyReturnsJob) do
      SendStaffDailyReturnsJob.perform_later
    end
  end
end
