# ABOUTME: Tests for SendStaffedDepartmentNotificationsJob.
# ABOUTME: Verifies queue assignment and enqueuing.

require "test_helper"

class SendStaffedDepartmentNotificationsJobTest < ActiveJob::TestCase
  test "uses default queue" do
    assert_equal "default", SendStaffedDepartmentNotificationsJob.new.queue_name
  end

  test "can be enqueued" do
    assert_enqueued_with(job: SendStaffedDepartmentNotificationsJob) do
      SendStaffedDepartmentNotificationsJob.perform_later
    end
  end
end
