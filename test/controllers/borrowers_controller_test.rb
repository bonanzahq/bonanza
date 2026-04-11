# ABOUTME: Integration tests for BorrowersController.
# ABOUTME: Covers CRUD, conduct management, self-registration, and email confirmation.

require "test_helper"

class BorrowersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    User.current_user = @user
    @borrower = create(:borrower, :with_tos, insurance_checked: true, id_checked: true)
  end

  # -- index --

  test "index requires authentication" do
    get borrowers_path
    assert_redirected_to new_user_session_path
  end

  test "index returns 200 for authenticated member" do
    sign_in @user
    get borrowers_path
    assert_response :success
  end

  test "guest is redirected from index" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    get borrowers_path
    assert_redirected_to public_home_page_path
  end

  test "guest is redirected from borrower show" do
    guest = create(:user, :guest, department: @department)
    sign_in guest
    get borrower_path(@borrower)
    assert_redirected_to public_home_page_path
  end

  test "borrower search result links have turbo-frame _top" do
    sign_in @user
    
    search_results = Kaminari.paginate_array([@borrower]).page(1).per(4)
    original_method = Borrower.method(:search_people)
    Borrower.define_singleton_method(:search_people) { |*_args| search_results }
    
    begin
      get borrowers_path, params: { q: @borrower.firstname }
      assert_response :success
      assert_select "a.name[href='#{borrower_path(@borrower)}'][data-turbo-frame='_top']"
    ensure
      Borrower.define_singleton_method(:search_people, original_method)
    end
  end

  # -- show --

  test "show renders borrower details" do
    sign_in @user
    get borrower_path(@borrower)
    assert_response :success
  end

  # -- new --

  test "new renders form" do
    sign_in @user
    get new_borrower_path
    assert_response :success
  end

  # -- create --

  test "create saves valid borrower" do
    sign_in @user

    assert_difference "Borrower.count", 1 do
      post borrowers_path, params: {
        borrower: {
          firstname: "Test",
          lastname: "Person",
          email: "new-borrower@example.com",
          phone: "0331 1234567",
          borrower_type: "employee"
        }
      }
    end
    assert_redirected_to borrower_url(Borrower.last)
  end

  test "create enqueues account_created_email" do
    sign_in @user

    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: ->(a) { a[0..1] == [ "BorrowerMailer", "account_created_email" ] }
    ) do
      post borrowers_path, params: {
        borrower: {
          firstname: "Email",
          lastname: "Test",
          email: "email-test-borrower@example.com",
          phone: "0331 9999999",
          borrower_type: "employee"
        }
      }
    end
  end

  test "create does not enqueue email on validation failure" do
    sign_in @user

    assert_no_enqueued_emails do
      post borrowers_path, params: {
        borrower: { firstname: "", lastname: "", email: "", phone: "" }
      }
    end
  end

  test "create rejects invalid borrower" do
    sign_in @user

    assert_no_difference "Borrower.count" do
      post borrowers_path, params: {
        borrower: { firstname: "", lastname: "", email: "", phone: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  # -- edit --

  test "edit renders form" do
    sign_in @user
    get edit_borrower_path(@borrower)
    assert_response :success
  end

  # -- update --

  test "update saves valid changes" do
    sign_in @user
    patch borrower_path(@borrower), params: {
      borrower: { firstname: "Updated" }
    }
    assert_redirected_to borrower_url(@borrower)

    @borrower.reload
    assert_equal "Updated", @borrower.firstname
  end

  test "update saves employee with empty student_id when another employee exists" do
    sign_in @user
    emp1 = create(:borrower, :employee, :with_tos)
    emp2 = create(:borrower, :employee, :with_tos)
    # Simulate a previous edit that set student_id to empty string
    emp1.update_column(:student_id, "")

    patch borrower_path(emp2), params: {
      borrower: {
        firstname: emp2.firstname,
        lastname: emp2.lastname,
        email: emp2.email,
        phone: emp2.phone,
        borrower_type: "employee",
        student_id: "",
        id_checked: "0",
        insurance_checked: "0",
        tos_accepted: "1"
      }
    }
    assert_redirected_to borrower_url(emp2)
    emp2.reload
    assert_nil emp2.student_id
  end

  # -- destroy --

  test "destroy removes borrower" do
    sign_in @user

    assert_difference "Borrower.count", -1 do
      delete borrower_path(@borrower)
    end
    assert_redirected_to borrowers_url
  end

  # -- add_conduct --

  test "add_conduct creates a conduct without lending" do
    sign_in @user

    assert_difference "Conduct.count", 1 do
      post borrower_add_conduct_path(@borrower), params: {
        conduct: { reason: "Zu spät zurückgegeben", permanent: true }
      }
    end

    assert_redirected_to borrower_path(@borrower)
    conduct = Conduct.last
    assert_nil conduct.lending_id
    assert_equal "banned", conduct.kind
    assert_equal @borrower, conduct.borrower
    assert_equal @department, conduct.department
  end

  # -- remove_conduct --

  test "remove_conduct lifts conduct instead of destroying it" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    conduct = create(:conduct, :banned, borrower: @borrower, department: @department, user: @user, lending: lending)
    sign_in @user

    assert_no_difference "Conduct.count" do
      delete borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
    end
    conduct.reload
    assert conduct.lifted?
    assert_equal @user, conduct.lifted_by
    assert_redirected_to borrower_path(@borrower)
  end

  test "remove_conduct rejects conduct from different department" do
    other_dept = create(:department)
    other_user = create(:user, department: other_dept)
    lending = create(:lending, :completed, user: other_user, department: other_dept, borrower: @borrower)
    conduct = create(:conduct, :banned, borrower: @borrower, department: other_dept, user: other_user, lending: lending)
    sign_in @user

    delete borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
    conduct.reload
    refute conduct.lifted?
  end

  # -- guest authorization --

  test "guest cannot create borrower" do
    guest = create(:user, :guest, department: @department)
    sign_in guest

    assert_no_difference "Borrower.count" do
      post borrowers_path, params: {
        borrower: {
          firstname: "Test", lastname: "Person",
          email: "guest-test@example.com", phone: "123",
          borrower_type: "employee"
        }
      }
    end
    assert_redirected_to public_home_page_path
  end

  # -- TOS link in staff form --

  test "new borrower form has TOS link" do
    sign_in @user
    get new_borrower_path
    assert_response :success
    assert_select "a[href='#{ausleihbedingungen_path}'][target='_blank']", text: "Ausleihbedingungen lesen"
  end

  test "edit borrower form has TOS link" do
    sign_in @user
    get edit_borrower_path(@borrower)
    assert_response :success
    assert_select "a[href='#{ausleihbedingungen_path}'][target='_blank']", text: "Ausleihbedingungen lesen"
  end

  # -- Public: self_register --

  test "self_register renders registration form without authentication" do
    get borrower_self_registration_path
    assert_response :success
  end

  test "self_register displays TOS content on page" do
    tos = LegalText.create!(kind: :tos, content: "**Testbedingungen** für die Ausleihe", user: @user)
    get borrower_self_registration_path
    assert_response :success
    assert_select ".tos-content", count: 1
    assert_select ".tos-content strong", text: "Testbedingungen"
  end

  # -- Public: self_create --

  test "self_create creates borrower with self context" do
    assert_difference "Borrower.count", 1 do
      post borrower_self_create_path, params: {
        borrower: {
          firstname: "Self",
          lastname: "Registrant",
          email: "self-reg@example.com",
          phone: "0331 9876543",
          borrower_type: "student",
          student_id: "s99999",
          tos_accepted: true
        }
      }
    end
    assert_redirected_to borrower_email_pending_url
  end

  test "self_create rejects without tos_accepted" do
    assert_no_difference "Borrower.count" do
      post borrower_self_create_path, params: {
        borrower: {
          firstname: "Self",
          lastname: "Registrant",
          email: "no-tos@example.com",
          phone: "0331 9876543",
          borrower_type: "student",
          student_id: "s99998",
          tos_accepted: false
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # -- Public: confirm_email --

  test "confirm_email with valid token clears token" do
    borrower = create(:borrower, :with_tos, email_token: "valid-token-123")
    get confirm_email_path(token: "valid-token-123")
    assert_response :success

    borrower.reload
    assert_nil borrower.email_token
  end

  test "confirm_email with invalid token redirects" do
    get confirm_email_path(token: "nonexistent-token")
    assert_redirected_to root_url
  end

  # -- Public: email_confirmation_pending --

  test "email_confirmation_pending renders" do
    get borrower_email_pending_path
    assert_response :success
  end

  # -- delete button label --

  test "show page has Benutzerdaten löschen button and modal" do
    sign_in @user
    get borrower_path(@borrower)
    assert_response :success
    assert_select "a", text: "Benutzerdaten löschen"
    assert_select ".modal-title", text: "Benutzerdaten löschen"
    assert_select "button[type=submit]", text: "Benutzerdaten löschen"
  end

  # -- GDPR: export_data --

  test "export_data creates an audit log entry" do
    sign_in @user

    assert_difference "GdprAuditLog.count", 1 do
      post export_data_borrower_path(@borrower)
    end

    log = GdprAuditLog.last
    assert_equal "export", log.action
    assert_equal @borrower, log.target
    assert_equal @user, log.performed_by
  end

  # -- GDPR: request_deletion --

  test "request_deletion creates audit log entries" do
    sign_in @user

    assert_difference "GdprAuditLog.count" do
      post request_deletion_borrower_path(@borrower)
    end

    assert GdprAuditLog.exists?(action: "deletion_requested", target: @borrower)
  end
end
