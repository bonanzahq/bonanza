# ABOUTME: Tests for Lending model notification class methods.
# ABOUTME: Covers overdue, upcoming return, staffed department, and confirmation email dispatch.

require "test_helper"

class LendingNotificationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @department = create(:department, staffed: true, staffed_at: 1.day.ago)
    @user = create(:user, department: @department)
    User.current_user = @user
    @borrower = create(:borrower, :with_tos)
  end

  # -- notify_borrowers_of_overdue_lending --

  test "notify_borrowers_of_overdue_lending enqueues email for overdue lending in staffed department" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_columns(lent_at: 20.days.ago, duration: 14)

    assert_enqueued_emails(1) do
      Lending.notify_borrowers_of_overdue_lending
    end
  end

  test "notify_borrowers_of_overdue_lending skips lending in unstaffed department" do
    unstaffed_dept = create(:department, staffed: false)
    user2 = create(:user, department: unstaffed_dept)
    lending = create(:lending, :completed, user: user2, department: unstaffed_dept, borrower: @borrower)
    lending.update_columns(lent_at: 20.days.ago, duration: 14)

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_overdue_lending
    end
  end

  test "notify_borrowers_of_overdue_lending skips already returned lending" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_columns(lent_at: 20.days.ago, duration: 14, returned_at: Time.current)

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_overdue_lending
    end
  end

  test "notify_borrowers_of_overdue_lending skips lending not yet due" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    # lent_at is Time.current and duration 14 from factory, not overdue

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_overdue_lending
    end
  end

  # -- notify_borrowers_of_upcoming_return --

  test "notify_borrowers_of_upcoming_return enqueues email for lending due tomorrow" do
    # lent 13 days ago with 14 day duration -> due tomorrow
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_columns(lent_at: 13.days.ago, duration: 14)

    assert_enqueued_emails(1) do
      Lending.notify_borrowers_of_upcoming_return
    end
  end

  test "notify_borrowers_of_upcoming_return skips lending due today" do
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_columns(lent_at: 14.days.ago, duration: 14)

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_upcoming_return
    end
  end

  test "notify_borrowers_of_upcoming_return skips lending in unstaffed department" do
    unstaffed_dept = create(:department, staffed: false)
    user2 = create(:user, department: unstaffed_dept)
    lending = create(:lending, :completed, user: user2, department: unstaffed_dept, borrower: @borrower)
    lending.update_columns(lent_at: 13.days.ago, duration: 14)

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_upcoming_return
    end
  end

  # -- notify_borrowers_of_staffed_department --

  test "notify_borrowers_of_staffed_department enqueues email for overdue lending when department reopened today" do
    dept = create(:department, staffed: true, staffed_at: Date.current.beginning_of_day)
    user2 = create(:user, department: dept)
    lending = create(:lending, :completed, user: user2, department: dept, borrower: @borrower)
    lending.update_columns(lent_at: 20.days.ago, duration: 14)

    assert_enqueued_emails(1) do
      Lending.notify_borrowers_of_staffed_department
    end
  end

  test "notify_borrowers_of_staffed_department skips lending when department reopened yesterday" do
    # @department has staffed_at: 1.day.ago (from setup)
    lending = create(:lending, :completed, user: @user, department: @department, borrower: @borrower)
    lending.update_columns(lent_at: 20.days.ago, duration: 14)

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_staffed_department
    end
  end

  test "notify_borrowers_of_staffed_department skips non-overdue lending" do
    dept = create(:department, staffed: true, staffed_at: Date.current.beginning_of_day)
    user2 = create(:user, department: dept)
    lending = create(:lending, :completed, user: user2, department: dept, borrower: @borrower)
    # default :completed factory: lent_at: Time.current, duration: 14 — not overdue

    assert_enqueued_emails(0) do
      Lending.notify_borrowers_of_staffed_department
    end
  end

  # -- confirmation email on finalize! --

  test "finalize! enqueues confirmation email" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item, quantity: 1)

    lending = create(:lending, user: @user, department: @department, borrower: @borrower,
                     state: :confirmation)
    create(:line_item, lending: lending, item: item)

    assert_enqueued_emails(1) do
      lending.update_from_checkout_params({ duration: 14 }, @user)
    end
  end
end
