# ABOUTME: Base class for all background jobs in the application.
# ABOUTME: Configures retry and discard behaviour shared across all jobs.

class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on Net::SMTPServerBusy, wait: 1.minute, attempts: 5
  retry_on Net::OpenTimeout, wait: 10.seconds, attempts: 3
  retry_on Errno::ECONNREFUSED, wait: 30.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
end
