# ABOUTME: Tests for the staging:anonymize rake task.
# ABOUTME: Verifies PII scrubbing, skip logic, idempotency, and safety guards.

require "test_helper"
require "rake"

class StagingAnonymizeTest < ActiveSupport::TestCase
  setup do
    BonanzaRedux::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["staging:anonymize"].reenable

    @department = create(:department)
    @user       = create(:user, department: @department)

    # Two borrowers that should be anonymized
    @student  = create(:borrower, firstname: "Alice", lastname: "Student",
                        email: "alice@example.com", phone: "111111",
                        student_id: "s99001", borrower_type: :student,
                        tos_accepted: true, insurance_checked: true,
                        id_checked: true)
    @employee = create(:borrower, :employee, firstname: "Bob", lastname: "Worker",
                        email: "bob@example.com", phone: "222222",
                        tos_accepted: true)

    # Already-anonymized borrower — should be skipped
    @anonymized = create(:borrower, :with_tos)
    @anonymized.update_columns(email: "deleted-999@anonymized.local",
                               firstname: "Geloescht", lastname: "Person")

    # Deleted (soft-deleted) borrower — should be skipped
    @deleted = create(:borrower, firstname: "Dave", lastname: "Deleted",
                       email: "dave@example.com", phone: "444444",
                       tos_accepted: true)
    @deleted.update_columns(borrower_type: :deleted)

    # Conduct linked to student borrower (conduct factory needs a lending)
    @conduct_lending = create(:lending, user: @user, department: @department)
    @conduct = create(:conduct, borrower: @student, department: @department,
                       user: @user, lending: @conduct_lending,
                       reason: "Leihfrist überschritten")

    # Lending with a note (note column set via update_columns to bypass validation)
    @lending_with_note = create(:lending, user: @user, department: @department)
    @lending_with_note.update_columns(note: "John picked up late")

    # Lending without a note
    @lending_no_note = create(:lending, user: @user, department: @department)

    # ItemHistory records
    @item = create(:item)
    @history_with_note = ItemHistory.create!(item: @item, note: "Returned by Jane Doe",
                                              status: :available, condition: :flawless)
    @history_no_note = ItemHistory.create!(item: @item, note: nil,
                                            status: :available, condition: :flawless)

    # GdprAuditLog record
    @audit_log = GdprAuditLog.create!(target: @student, action: "anonymize")
  end

  # -- helpers --

  def invoke_task
    previous_allow = ENV["ALLOW_ANONYMIZE"]

    Rake::Task["staging:anonymize"].reenable
    ENV["ALLOW_ANONYMIZE"] = "yes"
    Rake::Task["staging:anonymize"].invoke
  ensure
    if previous_allow
      ENV["ALLOW_ANONYMIZE"] = previous_allow
    else
      ENV.delete("ALLOW_ANONYMIZE")
    end
  end

  # -- tests --

  test "refuses to run without ALLOW_ANONYMIZE" do
    ENV.delete("ALLOW_ANONYMIZE")
    Rake::Task["staging:anonymize"].reenable
    assert_raises(SystemExit) do
      Rake::Task["staging:anonymize"].invoke
    end
  end

  test "refuses to run with wrong ALLOW_ANONYMIZE value" do
    ENV["ALLOW_ANONYMIZE"] = "NOWAY!!!"
    Rake::Task["staging:anonymize"].reenable
    assert_raises(SystemExit) do
      Rake::Task["staging:anonymize"].invoke
    end
  ensure
    ENV.delete("ALLOW_ANONYMIZE")
  end

  test "anonymizes borrower PII fields" do
    original_student_email    = @student.email
    original_student_id       = @student.student_id
    original_employee_email   = @employee.email

    invoke_task

    @student.reload
    @employee.reload

    assert_not_equal "Alice",             @student.firstname
    assert_not_equal "Student",           @student.lastname
    assert_not_equal original_student_email, @student.email
    assert_not_equal "111111",            @student.phone
    assert_nil @student.email_token
    assert_not_equal original_student_id, @student.student_id

    assert_not_equal "Bob",               @employee.firstname
    assert_not_equal "Worker",            @employee.lastname
    assert_not_equal original_employee_email, @employee.email
    assert_not_equal "222222",            @employee.phone
    assert_nil @employee.email_token
  end

  test "skips already-anonymized borrowers" do
    original_firstname = @anonymized.firstname
    original_lastname  = @anonymized.lastname

    invoke_task

    @anonymized.reload

    assert @anonymized.email.end_with?("@anonymized.local")
    assert_equal original_firstname, @anonymized.firstname
    assert_equal original_lastname,  @anonymized.lastname
  end

  test "skips deleted borrowers" do
    original_firstname = @deleted.firstname
    original_lastname  = @deleted.lastname
    original_email     = @deleted.email
    original_phone     = @deleted.phone

    invoke_task

    @deleted.reload

    assert_equal original_firstname, @deleted.firstname
    assert_equal original_lastname,  @deleted.lastname
    assert_equal original_email,     @deleted.email
    assert_equal original_phone,     @deleted.phone
  end

  test "anonymizes conduct reasons" do
    original_reason = @conduct.reason

    invoke_task

    @conduct.reload

    assert_not_equal original_reason, @conduct.reason
  end

  test "anonymizes lending notes" do
    invoke_task

    @lending_with_note.reload
    @lending_no_note.reload

    assert_not_equal "John picked up late", @lending_with_note.note
    assert_nil @lending_no_note.note
  end

  test "anonymizes item history notes" do
    invoke_task

    @history_with_note.reload
    @history_no_note.reload

    assert_not_equal "Returned by Jane Doe", @history_with_note.note
    assert_nil @history_no_note.note
  end

  test "deletes all GdprAuditLog records" do
    invoke_task

    assert_equal 0, GdprAuditLog.count
  end

  test "calls Borrower.reindex" do
    called = false
    Borrower.stub(:reindex, -> { called = true }) do
      invoke_task
    end
    assert called
  end

  test "is idempotent" do
    invoke_task

    @student.reload
    first_firstname = @student.firstname
    first_lastname  = @student.lastname
    first_email     = @student.email
    first_phone     = @student.phone

    invoke_task

    @student.reload

    assert_equal first_firstname, @student.firstname
    assert_equal first_lastname,  @student.lastname
    assert_equal first_email,     @student.email
    assert_equal first_phone,     @student.phone
  end

  test "preserves non-PII fields" do
    original_borrower_type      = @student.borrower_type
    original_tos_accepted       = @student.tos_accepted
    original_insurance_checked  = @student.insurance_checked
    original_id_checked         = @student.id_checked
    original_created_at         = @student.created_at

    invoke_task

    @student.reload

    assert_equal original_borrower_type,     @student.borrower_type
    assert_equal original_tos_accepted,      @student.tos_accepted
    assert_equal original_insurance_checked, @student.insurance_checked
    assert_equal original_id_checked,        @student.id_checked
    assert_equal original_created_at,        @student.created_at
  end
end
