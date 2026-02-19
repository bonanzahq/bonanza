# ABOUTME: Tests for Conduct model business logic.
# ABOUTME: Covers validations, kind enum, expiration logic, and warning escalation.

require "test_helper"

class ConductTest < ActiveSupport::TestCase
  # -- Enum --

  test "kind enum has expected values" do
    assert_equal({ "warned" => 0, "banned" => 1 }, Conduct.kinds)
  end

  # -- Factory --

  test "factory creates a valid conduct" do
    conduct = create(:conduct)
    assert conduct.persisted?
  end

  # -- Validations --

  test "requires reason" do
    conduct = build(:conduct, reason: nil)
    assert_not conduct.valid?
  end

  test "requires borrower" do
    conduct = build(:conduct, borrower: nil)
    assert_not conduct.valid?
  end

  test "requires department" do
    conduct = build(:conduct, department: nil)
    assert_not conduct.valid?
  end

  test "duration must be integer when present" do
    conduct = build(:conduct, duration: 1.5)
    assert_not conduct.valid?
  end

  test "duration allows nil" do
    conduct = create(:conduct, duration: nil, permanent: true)
    assert conduct.persisted?
  end

  # -- duration_or_perma custom validation --

  test "non-permanent conduct with no duration is invalid when user present" do
    conduct = build(:conduct, permanent: false, duration: nil)
    assert_not conduct.valid?
    assert conduct.errors[:permanent].any?
  end

  test "non-permanent conduct with positive duration is valid" do
    conduct = create(:conduct, permanent: false, duration: 7)
    assert conduct.persisted?
  end

  test "permanent conduct without duration is valid" do
    conduct = create(:conduct, permanent: true, duration: nil)
    assert conduct.persisted?
  end

  test "conduct without lending is valid" do
    conduct = create(:conduct, lending: nil, permanent: true)
    assert conduct.persisted?
    assert_nil conduct.lending_id
  end

  # -- expired? --

  test "expired? returns true when duration has passed" do
    conduct = create(:conduct, :expired, borrower: create(:borrower), department: create(:department), user: create(:user, department: create(:department)))
    assert conduct.expired?
  end

  test "expired? returns false when still valid" do
    conduct = create(:conduct, :with_duration, duration: 14)
    refute conduct.expired?
  end

  test "expired? returns false for permanent conduct" do
    conduct = create(:conduct, permanent: true)
    refute conduct.expired?
  end

  test "expired? returns false when no duration" do
    conduct = create(:conduct, :automatic, borrower: create(:borrower), department: create(:department))
    refute conduct.expired?
  end

  # -- days_remaining --

  test "days_remaining returns correct value" do
    conduct = create(:conduct, :with_duration, duration: 14)
    assert_in_delta 14, conduct.days_remaining, 1
  end

  test "days_remaining returns nil for permanent" do
    conduct = create(:conduct, permanent: true)
    assert_nil conduct.days_remaining
  end

  test "days_remaining returns 0 when expired" do
    conduct = create(:conduct, :expired, borrower: create(:borrower), department: create(:department), user: create(:user, department: create(:department)))
    assert_equal 0, conduct.days_remaining
  end

  # -- expiration_date --

  test "expiration_date returns correct date" do
    conduct = create(:conduct, :with_duration, duration: 14)
    assert_equal (conduct.created_at + 14.days).to_date, conduct.expiration_date
  end

  test "expiration_date returns nil for permanent" do
    conduct = create(:conduct, permanent: true)
    assert_nil conduct.expiration_date
  end

  # -- automatic? --

  test "automatic? returns true when user_id is nil" do
    conduct = create(:conduct, :automatic, borrower: create(:borrower), department: create(:department))
    assert conduct.automatic?
  end

  test "automatic? returns false when user is present" do
    conduct = create(:conduct, permanent: true)
    refute conduct.automatic?
  end

  # -- remove_expired --

  test "remove_expired destroys expired conducts with duration" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, :expired, borrower: borrower, department: department, user: user)
    valid = create(:conduct, :with_duration, borrower: borrower, department: department, user: user, duration: 14)

    removed = Conduct.remove_expired
    assert_equal 1, removed.size
    assert Conduct.exists?(valid.id)
  end

  test "remove_expired destroys stale automatic conducts" do
    borrower = create(:borrower)
    department = create(:department)
    stale = create(:conduct, :automatic, borrower: borrower, department: department)
    stale.update_column(:created_at, 61.days.ago)

    removed = Conduct.remove_expired
    assert_equal 1, removed.size
    refute Conduct.exists?(stale.id)
  end

  test "remove_expired does not destroy permanent conducts" do
    permanent = create(:conduct, permanent: true)
    Conduct.remove_expired
    assert Conduct.exists?(permanent.id)
  end

  # -- check_warning_escalation --

  test "check_warning_escalation creates ban after 2 warnings" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)

    # The after_create_commit callback fires check_warning_escalation when the second
    # warning is created, so the ban is already in the database at this point.
    ban = Conduct.where(borrower: borrower, department: department, kind: :banned).last
    assert ban.present?
    assert ban.banned?
    assert ban.automatic?
    assert_equal 30, ban.duration
  end

  test "check_warning_escalation does not create duplicate ban" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    create(:conduct, :banned, :with_duration, borrower: borrower, department: department, user: user)

    ban = Conduct.check_warning_escalation(borrower, department)
    assert_nil ban
  end

  test "check_warning_escalation returns nil for fewer than 2 warnings" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    assert_nil Conduct.check_warning_escalation(borrower, department)
  end
end
