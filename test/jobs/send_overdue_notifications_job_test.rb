# ABOUTME: Tests for SendOverdueNotificationsJob.
# ABOUTME: Verifies queue assignment and enqueuing.

require "test_helper"

class SendOverdueNotificationsJobTest < ActiveJob::TestCase
  test "uses default queue" do
    assert_equal "default", SendOverdueNotificationsJob.new.queue_name
  end

  test "can be enqueued" do
    assert_enqueued_with(job: SendOverdueNotificationsJob) do
      SendOverdueNotificationsJob.perform_later
    end
  end
end
