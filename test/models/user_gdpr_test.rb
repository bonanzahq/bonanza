# ABOUTME: Tests for GDPR-related User model methods.
# ABOUTME: Covers anonymize! and anonymized?.

require "test_helper"

class UserGdprTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
  end

  # -- anonymize! --

  test "anonymize! replaces personal fields with placeholder values" do
    @user.anonymize!
    @user.reload

    assert_equal "Ehemaliger", @user.firstname
    assert_equal "Mitarbeiter", @user.lastname
    assert_match(/@anonymized\.local$/, @user.email)
    assert_equal "", @user.encrypted_password
  end

  test "anonymize! sets all department memberships to deleted role" do
    second_department = create(:department)
    @user.department_memberships.find_by(department: second_department).update!(role: :leader)

    @user.anonymize!

    @user.department_memberships.reload.each do |membership|
      assert_equal "deleted", membership.role
    end
  end

  # -- anonymized? --

  test "anonymized? returns false before anonymization" do
    assert_not @user.anonymized?
  end

  test "anonymized? returns true after anonymization" do
    @user.anonymize!

    assert @user.anonymized?
  end
end
