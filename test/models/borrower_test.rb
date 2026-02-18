# ABOUTME: Tests for Borrower model business logic.
# ABOUTME: Covers validations, soft delete, TOS, fullname, conduct queries.

require "test_helper"

class BorrowerTest < ActiveSupport::TestCase
  setup do
    @borrower = build(:borrower)
  end

  # -- Enums --

  test "borrower_type enum has expected values" do
    assert_equal({ "student" => 0, "employee" => 1, "deleted" => 2 }, Borrower.borrower_types)
  end

  # -- Presence validations --

  test "requires firstname" do
    @borrower.firstname = nil
    assert_not @borrower.valid?
  end

  test "requires lastname" do
    @borrower.lastname = nil
    assert_not @borrower.valid?
  end

  test "requires email" do
    @borrower.email = nil
    assert_not @borrower.valid?
  end

  test "requires phone" do
    @borrower.phone = nil
    assert_not @borrower.valid?
  end

  # -- Insurance --

  test "insurance_checked must be true" do
    @borrower.insurance_checked = false
    assert_not @borrower.valid?
  end

  # -- Student-specific validations --

  test "student requires id_checked" do
    @borrower.id_checked = false
    assert_not @borrower.valid?
  end

  test "student requires student_id" do
    @borrower.student_id = nil
    assert_not @borrower.valid?
  end

  test "student_id must be unique among students" do
    create(:borrower, student_id: "s99999")
    duplicate = build(:borrower, student_id: "s99999")

    assert_not duplicate.valid?
  end

  # -- Employee validations --

  test "employee does not require id_checked" do
    borrower = build(:borrower, :employee)
    borrower.id_checked = false

    assert borrower.valid?
  end

  test "employee does not require student_id" do
    borrower = build(:borrower, :employee)

    assert_nil borrower.student_id
    assert borrower.valid?
  end

  # -- Email uniqueness --

  test "email must be unique" do
    create(:borrower, email: "dupe@example.com")
    duplicate = build(:borrower, email: "dupe@example.com")

    assert_not duplicate.valid?
  end

  # -- TOS validation --

  test "tos_accepted validation only runs on :self context" do
    @borrower.tos_accepted = false
    assert @borrower.valid?, "tos_accepted should not be checked on default context"

    assert_not @borrower.valid?(:self), "tos_accepted should be checked on :self context"
  end

  # -- Fullname --

  test "fullname concatenates first and last name" do
    @borrower.firstname = "Max"
    @borrower.lastname = "Mustermann"

    assert_equal "Max Mustermann", @borrower.fullname
  end

  # -- TOS callback --

  test "tos_accepted_at is set when tos_accepted is true" do
    @borrower.tos_accepted = true
    @borrower.save!

    assert @borrower.tos_accepted_at.present?
  end

  test "tos_accepted_at is not set when tos_accepted is false" do
    @borrower.save!

    assert_nil @borrower.tos_accepted_at
  end

  # -- Soft delete --

  test "borrower can be soft-deleted via borrower_type" do
    @borrower.save!
    @borrower.deleted!

    assert @borrower.deleted?
    assert @borrower.persisted?
  end

  # -- Conduct queries --

  test "has_misconduct_in? returns true with conducts in department" do
    department = create(:department)
    @borrower.save!
    create(:conduct, borrower: @borrower, department: department)

    assert @borrower.has_misconduct_in?(department)
  end

  test "has_misconduct_in? returns false without conducts" do
    department = create(:department)
    @borrower.save!

    assert_not @borrower.has_misconduct_in?(department)
  end

  test "has_bans_in? only matches banned conducts" do
    department = create(:department)
    @borrower.save!
    create(:conduct, borrower: @borrower, department: department, kind: :warned)

    assert_not @borrower.has_bans_in?(department)

    create(:conduct, :banned, borrower: @borrower, department: department)

    assert @borrower.has_bans_in?(department)
  end

  # -- send_confirmation_pending_email --

  test "send_confirmation_pending_email adds error and returns false on mail failure" do
    @borrower.save!

    # Stub deliver_now to simulate SMTP failure
    failing_mail = Object.new
    failing_mail.define_singleton_method(:deliver_now) { raise Errno::ECONNREFUSED, "Connection refused" }

    mailer_proxy = Object.new
    mailer_proxy.define_singleton_method(:confirm_email) { failing_mail }

    BorrowerMailer.stub(:with, ->(_) { mailer_proxy }) do
      result = @borrower.send_confirmation_pending_email

      assert_equal false, result
      assert @borrower.errors[:base].any?, "should add error to model"
    end
  end

  test "send_confirmation_pending_email creates token" do
    @borrower.save!
    @borrower.send_confirmation_pending_email

    assert @borrower.email_token.present?
  end

  test "has_warnings_in? only matches warned conducts" do
    department = create(:department)
    @borrower.save!
    create(:conduct, :banned, borrower: @borrower, department: department)

    assert_not @borrower.has_warnings_in?(department)

    create(:conduct, borrower: @borrower, department: department, kind: :warned)

    assert @borrower.has_warnings_in?(department)
  end
end
