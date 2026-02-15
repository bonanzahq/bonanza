# ABOUTME: Integration tests for BorrowersController.
# ABOUTME: Covers CRUD, conduct management, self-registration, and email confirmation.

require "test_helper"

class BorrowersControllerTest < ActionDispatch::IntegrationTest
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

  test "borrower search result links have turbo-frame _top" do
    sign_in @user
    
    # Stub search to return a kaminari-paginated collection
    search_results = Kaminari.paginate_array([@borrower]).page(1).per(4)
    original_method = Borrower.method(:search_people)
    Borrower.define_singleton_method(:search_people) { |*args| search_results }
    
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
          borrower_type: "employee",
          insurance_checked: true
        }
      }
    end
    assert_redirected_to borrower_url(Borrower.last)
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

  # -- destroy --

  test "destroy removes borrower" do
    sign_in @user

    assert_difference "Borrower.count", -1 do
      delete borrower_path(@borrower)
    end
    assert_redirected_to borrowers_url
  end

  # -- add_conduct --

  # NOTE: add_conduct is broken -- the DB requires lending_id NOT NULL but the
  # controller never sets it. Filed as git-bug ca344d3. This test documents the crash.
  test "add_conduct returns 500 due to missing lending_id" do
    sign_in @user

    post borrower_add_conduct_path(@borrower), params: {
      conduct: { reason: "Zu spät zurückgegeben", permanent: true }
    }
    
    assert_response :internal_server_error
  end

  # -- remove_conduct --

  test "remove_conduct removes conduct scoped to current department" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    conduct = create(:conduct, :banned, borrower: @borrower, department: @department, user: @user, lending: lending)
    sign_in @user

    assert_difference "Conduct.count", -1 do
      get borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
    end
    assert_redirected_to borrower_path(@borrower)
  end

  test "remove_conduct rejects conduct from different department" do
    other_dept = create(:department)
    other_user = create(:user, department: other_dept)
    lending = create(:lending, :completed, user: other_user, department: other_dept, borrower: @borrower)
    conduct = create(:conduct, :banned, borrower: @borrower, department: other_dept, user: other_user, lending: lending)
    sign_in @user

    assert_no_difference "Conduct.count" do
      get borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
    end
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
          borrower_type: "employee", insurance_checked: true
        }
      }
    end
    assert_redirected_to public_home_page_path
  end

  # -- Public: self_register --

  test "self_register renders registration form without authentication" do
    get borrower_self_registration_path
    assert_response :success
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
end
