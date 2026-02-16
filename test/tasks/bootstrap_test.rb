# ABOUTME: Tests for the bootstrap:admin rake task.
# ABOUTME: Verifies production admin creation from environment variables.

require "test_helper"
require "rake"

class BootstrapTest < ActiveSupport::TestCase
  setup do
    BonanzaRedux::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["bootstrap:admin"].reenable
    @department = create(:department)
  end

  teardown do
    ENV.delete("ADMIN_EMAIL")
    ENV.delete("ADMIN_PASSWORD")
  end

  test "creates admin user when no admin exists" do
    User.where(admin: true).delete_all

    ENV["ADMIN_EMAIL"] = "admin@bonanza.test"
    ENV["ADMIN_PASSWORD"] = "secure_password123"

    Rake::Task["bootstrap:admin"].invoke

    assert_equal 1, User.where(admin: true).count
    admin = User.find_by(admin: true)
    assert_equal "admin@bonanza.test", admin.email
  end

  test "creates legal texts when no admin exists" do
    User.where(admin: true).delete_all
    LegalText.destroy_all

    ENV["ADMIN_EMAIL"] = "admin@bonanza.test"
    ENV["ADMIN_PASSWORD"] = "secure_password123"

    Rake::Task["bootstrap:admin"].invoke

    assert_equal 3, LegalText.count
    assert LegalText.find_by(kind: "tos").present?
    assert LegalText.find_by(kind: "privacy").present?
    assert LegalText.find_by(kind: "imprint").present?
  end

  test "skips when admin already exists" do
    create(:user, :admin)
    initial_count = User.count

    ENV["ADMIN_EMAIL"] = "admin@bonanza.test"
    ENV["ADMIN_PASSWORD"] = "secure_password123"

    Rake::Task["bootstrap:admin"].invoke

    assert_equal initial_count, User.count
  end

  test "aborts when ADMIN_EMAIL is missing" do
    User.where(admin: true).delete_all

    ENV["ADMIN_PASSWORD"] = "secure_password123"

    assert_raises(SystemExit) do
      Rake::Task["bootstrap:admin"].invoke
    end
  end

  test "aborts when ADMIN_PASSWORD is missing" do
    User.where(admin: true).delete_all

    ENV["ADMIN_EMAIL"] = "admin@bonanza.test"

    assert_raises(SystemExit) do
      Rake::Task["bootstrap:admin"].invoke
    end
  end

  test "creates default department if none exists" do
    User.where(admin: true).delete_all
    Department.destroy_all

    ENV["ADMIN_EMAIL"] = "admin@bonanza.test"
    ENV["ADMIN_PASSWORD"] = "secure_password123"

    Rake::Task["bootstrap:admin"].invoke

    assert_equal 1, Department.count
    dept = Department.first
    assert_equal "Standard", dept.name
    assert_equal "TBD", dept.room
    assert_equal 14, dept.default_lending_duration
  end
end
