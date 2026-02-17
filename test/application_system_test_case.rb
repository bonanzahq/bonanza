# ABOUTME: Base class for system tests with headless Chrome.
# ABOUTME: Provides browser-based sign-in helper for Devise authentication.

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def sign_in_as(user, password: "platypus-umbrella-cactus")
    visit new_user_session_path
    fill_in "E-Mail", with: user.email
    fill_in "Passwort", with: password
    click_button "Anmelden"
  end
end
