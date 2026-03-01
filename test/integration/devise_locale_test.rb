# ABOUTME: Tests that Devise pages render German text.
# ABOUTME: Verifies locale files, shared links, and mailer templates use German translations.

require "test_helper"

class DeviseLocaleTest < ActionDispatch::IntegrationTest
  test "login page renders German text" do
    get new_user_session_path
    assert_response :success
    assert_select "h3", text: "Anmelden"
    assert_select 'input[value="Anmelden"]'
  end

  test "password reset page renders German text" do
    get new_user_password_path
    assert_response :success
    assert_select "h3", text: "Passwort zurücksetzen"
    assert_select 'input[value="E-Mail zum Passwortzurücksetzen anfordern"]'
  end

  test "password reset page shared links render German text" do
    get new_user_password_path
    assert_response :success
    assert_select "a", text: I18n.t("devise.shared.links.sign_in")
    assert_no_match(/Log in/, response.body)
    assert_no_match(/Sign up/, response.body)
    assert_no_match(/Forgot your password\?/, response.body)
  end

  test "devise_invitable German locale file is loaded" do
    assert_equal "Eine Einladungs-E-Mail wurde an %{email} gesendet.",
      I18n.t("devise.invitations.send_instructions", locale: :de)
    assert_equal "Der Einladungs-Token ist ungültig!",
      I18n.t("devise.invitations.invitation_token_invalid", locale: :de)
    assert_equal "Dein Passwort wurde erfolgreich gespeichert. Du bist jetzt angemeldet.",
      I18n.t("devise.invitations.updated", locale: :de)
    assert_equal "Du hast eine ausstehende Einladung. Nimm sie an, um Dein Konto zu erstellen.",
      I18n.t("devise.failure.invited", locale: :de)
  end

  test "devise_invitable mailer translations are German" do
    assert_equal "Einladung zu Bonanza",
      I18n.t("devise.mailer.invitation_instructions.subject", locale: :de)
    assert_equal "Einladung annehmen",
      I18n.t("devise.mailer.invitation_instructions.accept", locale: :de)
  end

  test "reset password email template contains German text" do
    department = Department.create!(name: "Test Dept")
    user = User.new(
      email: "locale-test@example.com",
      password: "platypus-umbrella-cactus",
      password_confirmation: "platypus-umbrella-cactus",
      firstname: "Test",
      lastname: "User"
    )
    user.department_memberships.build(department: department, role: :member)
    user.save!

    user.send_reset_password_instructions

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail, "Expected a reset password email to be sent"
    body = mail.body.encoded
    assert_includes body, "Passwort zurücksetzen"
    assert_includes body, "Passwort zu ändern"
    assert_no_match(/Hello/, body)
    assert_no_match(/Change my password/, body)
  end

end
