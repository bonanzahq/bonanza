# ABOUTME: Tests for SendUpcomingReturnRemindersJob.
# ABOUTME: Verifies queue assignment and enqueuing.

require "test_helper"

class SendUpcomingReturnRemindersJobTest < ActiveJob::TestCase
  test "uses default queue" do
    assert_equal "default", SendUpcomingReturnRemindersJob.new.queue_name
  end

  test "can be enqueued" do
    assert_enqueued_with(job: SendUpcomingReturnRemindersJob) do
      SendUpcomingReturnRemindersJob.perform_later
    end
  end
end
