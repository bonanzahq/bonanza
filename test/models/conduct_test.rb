# ABOUTME: Tests for Conduct model business logic.
# ABOUTME: Covers validations, kind enum, expiration logic, warning escalation, and soft-delete lifting.

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
    # Second warning triggers escalation via after_create_commit, which creates the auto-ban.
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    assert Conduct.where(borrower: borrower, department: department, kind: :banned).exists?

    ban = Conduct.check_warning_escalation(borrower, department)
    assert_nil ban
  end

  # -- uniqueness of banned conducts per department --

  test "second banned conduct for same borrower and department is invalid" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, :banned, :with_duration, borrower: borrower, department: department, user: user)

    duplicate = build(:conduct, :banned, :with_duration, borrower: borrower, department: department, user: user)
    assert_not duplicate.valid?
    assert duplicate.errors[:borrower_id].any?
  end

  test "warnings allow multiple per borrower and department" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)

    second_warning = build(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    assert second_warning.valid?
  end

  test "banned conduct for different department is valid" do
    borrower = create(:borrower)
    dept_a = create(:department)
    dept_b = create(:department)
    user_a = create(:user, department: dept_a)
    user_b = create(:user, department: dept_b)
    create(:conduct, :banned, :with_duration, borrower: borrower, department: dept_a, user: user_a)

    second_ban = build(:conduct, :banned, :with_duration, borrower: borrower, department: dept_b, user: user_b)
    assert second_ban.valid?
  end

  test "check_warning_escalation returns nil for fewer than 2 warnings" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    assert_nil Conduct.check_warning_escalation(borrower, department)
  end

  # -- lift! --

  test "lift! sets lifted_at and lifted_by" do
    conduct = create(:conduct, :banned, :with_duration)
    lifter = create(:user, department: create(:department))

    conduct.lift!(lifter)

    assert conduct.lifted_at.present?
    assert_equal lifter, conduct.lifted_by
    assert conduct.persisted?
    refute conduct.destroyed?
  end

  test "lifted? returns true for lifted conduct" do
    conduct = create(:conduct, :banned, :with_duration)
    lifter = create(:user, department: create(:department))
    conduct.lift!(lifter)

    assert conduct.lifted?
  end

  test "lifted? returns false for active conduct" do
    conduct = create(:conduct, :banned, :with_duration)
    refute conduct.lifted?
  end

  # -- scopes --

  test "active scope excludes lifted conducts" do
    active = create(:conduct, :banned, :with_duration)
    lifted = create(:conduct, :banned, :with_duration, borrower: create(:borrower))
    lifted.update!(lifted_at: Time.current, lifted_by: create(:user, department: create(:department)))

    assert_includes Conduct.active, active
    assert_not_includes Conduct.active, lifted
  end

  test "lifted scope returns only lifted conducts" do
    active = create(:conduct, :banned, :with_duration)
    lifted = create(:conduct, :banned, :with_duration, borrower: create(:borrower))
    lifted.update!(lifted_at: Time.current, lifted_by: create(:user, department: create(:department)))

    assert_includes Conduct.lifted, lifted
    assert_not_includes Conduct.lifted, active
  end

  # -- uniqueness only for active bans --

  test "second ban is valid when first ban is lifted" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    first_ban = create(:conduct, :banned, :with_duration, borrower: borrower, department: department, user: user)
    first_ban.update!(lifted_at: Time.current, lifted_by: user)

    second_ban = build(:conduct, :banned, :with_duration, borrower: borrower, department: department, user: user)
    assert second_ban.valid?
  end

  # -- remove_expired skips lifted --

  test "remove_expired skips lifted conducts" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    conduct = create(:conduct, :expired, borrower: borrower, department: department, user: user)
    conduct.update!(lifted_at: Time.current, lifted_by: user)

    removed = Conduct.remove_expired
    assert_equal 0, removed.size
    assert Conduct.exists?(conduct.id)
  end

  # -- check_warning_escalation ignores lifted bans --

  test "check_warning_escalation creates ban when existing ban is lifted" do
    borrower = create(:borrower)
    department = create(:department)
    user = create(:user, department: create(:department))
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)
    create(:conduct, borrower: borrower, department: department, user: user, kind: :warned, permanent: true)

    # An auto-ban was created by the callback. Lift it.
    auto_ban = Conduct.where(borrower: borrower, department: department, kind: :banned).first!
    auto_ban.update!(lifted_at: Time.current, lifted_by: user)

    # Now escalation should create a new ban since the old one is lifted.
    new_ban = Conduct.check_warning_escalation(borrower, department)
    assert new_ban.present?
    assert new_ban.banned?
  end
end
