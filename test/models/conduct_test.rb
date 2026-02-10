# ABOUTME: Tests for Conduct model business logic.
# ABOUTME: Covers validations, kind enum, duration/permanent custom validation.

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
end
