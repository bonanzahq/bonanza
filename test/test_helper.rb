# ABOUTME: Global test configuration for Minitest.
# ABOUTME: Sets up FactoryBot, Devise helpers, and disables Searchkick callbacks.

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  parallelize(workers: :number_of_processors)

  self.use_transactional_tests = true

  setup do
    Searchkick.disable_callbacks
    User.current_user = nil
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
