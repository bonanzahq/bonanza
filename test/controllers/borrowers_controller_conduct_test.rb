# ABOUTME: Tests for conduct email wiring in BorrowersController and Conduct model.
# ABOUTME: Verifies ban/lift notifications are enqueued and warning escalation sends auto-ban email.

require "test_helper"

class BorrowersControllerConductTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    User.current_user = @user
    @borrower = create(:borrower, :with_tos, insurance_checked: true, id_checked: true)
  end

  # -- add_conduct email --

  test "add_conduct enqueues ban_notification_email" do
    sign_in @user

    assert_enqueued_emails 1 do
      post borrower_add_conduct_path(@borrower), params: {
        conduct: { reason: "Zu spät zurückgegeben", permanent: true }
      }
    end
  end

  test "add_conduct actually delivers ban_notification_email (job can be performed after conduct is saved)" do
    sign_in @user

    assert_emails 1 do
      perform_enqueued_jobs do
        post borrower_add_conduct_path(@borrower), params: {
          conduct: { reason: "Zu spät zurückgegeben", permanent: true }
        }
      end
    end
  end

  test "add_conduct does not enqueue email when conduct is invalid" do
    sign_in @user

    assert_enqueued_emails 0 do
      post borrower_add_conduct_path(@borrower), params: {
        conduct: { reason: "", permanent: false, duration: nil }
      }
    end
  end

  # -- remove_conduct email --

  test "remove_conduct enqueues ban_lifted_notification_email" do
    conduct = create(:conduct, :banned, borrower: @borrower, department: @department, user: @user, permanent: true)
    sign_in @user

    assert_enqueued_emails 1 do
      get borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
    end
  end

  test "remove_conduct actually delivers ban_lifted_notification_email (job can be performed after conduct is destroyed)" do
    conduct = create(:conduct, :banned, borrower: @borrower, department: @department, user: @user, permanent: true)
    sign_in @user

    assert_emails 1 do
      perform_enqueued_jobs do
        get borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
      end
    end
  end

  test "remove_conduct does not enqueue email for conduct from different department" do
    other_dept = create(:department)
    other_user = create(:user, department: other_dept)
    conduct = create(:conduct, :banned, borrower: @borrower, department: other_dept, user: other_user, permanent: true)
    sign_in @user

    assert_enqueued_emails 0 do
      get borrower_remove_conduct_path(@borrower, conducts_id: conduct.id)
    end
  end

  # -- warning escalation auto-ban email --

  test "creating second warning triggers escalation and enqueues auto_ban_notification_email" do
    create(:conduct, borrower: @borrower, department: @department, user: @user, kind: :warned, permanent: true)

    assert_enqueued_emails 1 do
      create(:conduct, borrower: @borrower, department: @department, user: @user, kind: :warned, permanent: true)
    end

    enqueued = enqueued_jobs.last
    assert_equal "ActionMailer::MailDeliveryJob", enqueued[:job].to_s
    assert_equal "BorrowerMailer", enqueued[:args].first
    assert_equal "auto_ban_notification_email", enqueued[:args].second
  end

  test "creating first warning does not enqueue auto_ban_notification_email" do
    assert_enqueued_emails 0 do
      create(:conduct, borrower: @borrower, department: @department, user: @user, kind: :warned, permanent: true)
    end
  end
end
