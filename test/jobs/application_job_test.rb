# ABOUTME: Tests for ApplicationJob base class behaviour.
# ABOUTME: Verifies that jobs can be enqueued using the test adapter.

require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  # A minimal concrete job for testing enqueue behaviour.
  class NoOpJob < ApplicationJob
    queue_as :default

    def perform; end
  end

  test "job can be enqueued" do
    assert_enqueued_with(job: NoOpJob) do
      NoOpJob.perform_later
    end
  end

  test "job is enqueued to the default queue" do
    assert_enqueued_with(job: NoOpJob, queue: "default") do
      NoOpJob.perform_later
    end
  end
end
