# ABOUTME: Global test configuration for Minitest.
# ABOUTME: Sets up FactoryBot, Devise helpers, and disables Searchkick callbacks.

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

# Ensure routes are loaded for Devise to register mappings
Rails.application.reload_routes!

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  parallelize(workers: 1)

  self.use_transactional_tests = true

  setup do
    Searchkick.disable_callbacks
    User.current_user = nil
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
