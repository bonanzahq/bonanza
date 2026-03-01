# ABOUTME: Tests for Devise mailer templates (styled HTML emails).
# ABOUTME: Verifies German content, branded layout, CTA buttons, and plain-text fallback URLs.

require "test_helper"

class DeviseMailerTest < ActionMailer::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
  end

  # reset_password_instructions

  test "reset_password_instructions renders" do
    email = Devise::Mailer.reset_password_instructions(@user, "raw_token", {})
    assert_not_nil email
  end

  test "reset_password_instructions is addressed to the user" do
    email = Devise::Mailer.reset_password_instructions(@user, "raw_token", {})
    assert_equal [ @user.email ], email.to
  end

  test "reset_password_instructions body contains heading" do
    email = Devise::Mailer.reset_password_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "Passwort zurücksetzen"
  end

  test "reset_password_instructions body contains greeting" do
    email = Devise::Mailer.reset_password_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "Hallo,"
  end

  test "reset_password_instructions body contains reset_password_token URL" do
    email = Devise::Mailer.reset_password_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "reset_password_token"
  end

  test "reset_password_instructions body contains plain-text fallback URL" do
    email = Devise::Mailer.reset_password_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "Oder kopiere diesen Link in Deinen Browser:"
  end

  # password_change

  test "password_change renders" do
    email = Devise::Mailer.password_change(@user, {})
    assert_not_nil email
  end

  test "password_change is addressed to the user" do
    email = Devise::Mailer.password_change(@user, {})
    assert_equal [ @user.email ], email.to
  end

  test "password_change body contains heading" do
    email = Devise::Mailer.password_change(@user, {})
    assert_includes email.body.decoded, "Passwort geändert"
  end

  test "password_change body contains user email in greeting" do
    email = Devise::Mailer.password_change(@user, {})
    assert_includes email.body.decoded, @user.email
  end

  test "password_change body contains notification text" do
    email = Devise::Mailer.password_change(@user, {})
    assert_includes email.body.decoded, "Passwort bei Bonanza geändert"
  end

  # confirmation_instructions

  test "confirmation_instructions renders" do
    email = Devise::Mailer.confirmation_instructions(@user, "raw_token", {})
    assert_not_nil email
  end

  test "confirmation_instructions is addressed to the user" do
    email = Devise::Mailer.confirmation_instructions(@user, "raw_token", {})
    assert_equal [ @user.email ], email.to
  end

  test "confirmation_instructions body contains heading for initial confirmation" do
    @user.unconfirmed_email = nil
    email = Devise::Mailer.confirmation_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "Konto bestätigen"
  end

  test "confirmation_instructions body contains confirmation URL" do
    email = Devise::Mailer.confirmation_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "confirmation"
  end

  test "confirmation_instructions body contains plain-text fallback URL" do
    email = Devise::Mailer.confirmation_instructions(@user, "raw_token", {})
    assert_includes email.body.decoded, "Oder kopiere diesen Link in Deinen Browser:"
  end

  # invitation_instructions

  test "invitation_instructions renders" do
    email = Devise::Mailer.invitation_instructions(build_invitee_with_inviter, "raw_token", {})
    assert_not_nil email
  end

  test "invitation_instructions is addressed to the invitee" do
    invitee = build_invitee_with_inviter
    email = Devise::Mailer.invitation_instructions(invitee, "raw_token", {})
    assert_equal [ invitee.email ], email.to
  end

  test "invitation_instructions body contains invitation heading" do
    email = Devise::Mailer.invitation_instructions(build_invitee_with_inviter, "raw_token", {})
    assert_includes email.body.decoded, "eingeladen"
  end

  test "invitation_instructions body contains accept_invitation URL" do
    email = Devise::Mailer.invitation_instructions(build_invitee_with_inviter, "raw_token", {})
    assert_includes email.body.decoded, "invitation"
  end

  test "invitation_instructions body contains plain-text fallback URL" do
    email = Devise::Mailer.invitation_instructions(build_invitee_with_inviter, "raw_token", {})
    assert_includes email.body.decoded, "Oder kopiere diesen Link in Deinen Browser:"
  end

  # email_changed

  test "email_changed renders" do
    email = Devise::Mailer.email_changed(@user, {})
    assert_not_nil email
  end

  test "email_changed is addressed to the user" do
    email = Devise::Mailer.email_changed(@user, {})
    assert_equal [ @user.email ], email.to
  end

  test "email_changed body contains heading" do
    email = Devise::Mailer.email_changed(@user, {})
    assert_includes email.body.decoded, "E-Mail-Adresse geändert"
  end

  test "email_changed body contains user email" do
    email = Devise::Mailer.email_changed(@user, {})
    assert_includes email.body.decoded, @user.email
  end

  private

  def build_invitee_with_inviter
    inviter = create(:user, department: @department)
    invitee = build(:user, department: @department)
    invitee.invited_by = inviter
    invitee.current_department = @department
    invitee.save!(validate: false)
    invitee
  end
end
