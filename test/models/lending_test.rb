# ABOUTME: Tests for Lending model business logic.
# ABOUTME: Covers state machine, token, populate, overdue, validations, scopes.

require "test_helper"

class LendingTest < ActiveSupport::TestCase
  setup do
    @department = create(:department)
    @user = create(:user, department: @department)
    User.current_user = @user
    @lending = create(:lending, user: @user, department: @department)
  end

  # -- Enums --

  test "state enum has expected values" do
    assert_equal({ "cart" => 0, "borrower" => 1, "confirmation" => 2, "completed" => 3 }, Lending.states)
  end

  # -- Token --

  test "token is generated on create" do
    assert @lending.token.present?
    assert @lending.token.length > 10
  end

  test "each lending gets a unique token" do
    other = create(:lending, user: @user, department: @department)
    assert_not_equal @lending.token, other.token
  end

  # -- State transitions --

  test "can_go_to_state? allows current state" do
    assert @lending.can_go_to_state?("cart")
  end

  test "can_go_to_state? rejects forward state" do
    assert_not @lending.can_go_to_state?("borrower")
  end

  test "can_go_to_state? allows previous state from later state" do
    @lending.update_column(:state, Lending.states[:confirmation])
    @lending.reload

    assert @lending.can_go_to_state?("cart")
    assert @lending.can_go_to_state?("borrower")
    assert @lending.can_go_to_state?("confirmation")
  end

  test "can_go_to_state? rejects invalid state names" do
    assert_not @lending.can_go_to_state?("nonexistent")
    assert_not @lending.can_go_to_state?(nil)
    assert_not @lending.can_go_to_state?("")
  end

  test "advance moves state forward by one" do
    @lending.advance
    assert_equal "borrower", @lending.state
  end

  test "advance to confirmation blocked without borrower" do
    @lending.update_column(:state, Lending.states[:borrower])
    @lending.reload

    result = @lending.advance
    assert_equal false, result
  end

  test "advance to confirmation succeeds with borrower" do
    borrower = create(:borrower, :with_tos)
    @lending.update_column(:state, Lending.states[:borrower])
    @lending.reload
    @lending.borrower = borrower

    result = @lending.advance
    assert result
    assert_equal "confirmation", @lending.state
  end

  # -- is_overdue? --

  test "is_overdue? returns false when not yet lent" do
    assert_not @lending.is_overdue?
  end

  test "is_overdue? returns false when within duration" do
    @lending.update_columns(lent_at: 1.day.ago, duration: 14)
    @lending.reload

    assert_not @lending.is_overdue?
  end

  test "is_overdue? returns true when past due" do
    @lending.update_columns(lent_at: 20.days.ago, duration: 14)
    @lending.reload

    assert @lending.is_overdue?
  end

  test "is_overdue? returns false when duration is nil" do
    @lending.update_columns(lent_at: 1.day.ago, duration: nil)
    @lending.reload

    assert_not @lending.is_overdue?
  end

  # -- has_line_items? --

  test "has_line_items? returns false for empty lending" do
    assert_not @lending.has_line_items?
  end

  test "has_line_items? returns true with line items" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    create(:line_item, lending: @lending, item: item)

    assert @lending.has_line_items?
  end

  # -- Scopes --

  test "unfinished scope returns lendings without lent_at" do
    lent = create(:lending, :completed, user: @user, department: @department)

    unfinished = Lending.unfinished
    assert_includes unfinished, @lending
    assert_not_includes unfinished, lent
  end

  # -- populate --

  test "populate adds item to cart" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item, quantity: 5)

    result = @lending.populate(item.id, 2)
    assert result
    assert_equal 1, @lending.line_items.size
    assert_equal 2, @lending.line_items.first.quantity
  end

  test "populate increments existing line item quantity" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item, quantity: 5)

    @lending.populate(item.id, 2)
    @lending.save!

    line_item = @lending.populate(item.id, 1)
    assert_equal 3, line_item.quantity
  end

  test "populate rejects zero quantity" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)

    result = @lending.populate(item.id, 0)
    assert_equal false, result
  end

  test "populate rejects unavailable item" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item, status: :lent)

    result = @lending.populate(item.id, 1)
    assert_equal false, result
  end

  test "populate rejects item from different department" do
    other_dept = create(:department)
    parent_item = create(:parent_item, department: other_dept)
    item = create(:item, parent_item: parent_item)

    result = @lending.populate(item.id, 1)
    assert_equal false, result
  end

  test "populate rejects nonexistent item" do
    @lending.populate(999999)
    assert @lending.errors[:item].any?
  end

  test "populate rejects when department is not staffed" do
    @department.update_column(:staffed, false)
    @department.reload
    @user.reload

    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)

    result = @lending.populate(item.id, 1)
    assert_equal false, result
  end

  test "populate rejects quantity exceeding available stock" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item, quantity: 2)

    result = @lending.populate(item.id, 3)
    assert_equal false, result
  end

  # -- all_items_returned? --

  test "all_items_returned? sets returned_at when all line items returned" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    create(:line_item, lending: @lending, item: item, returned_at: Time.current)

    @lending.all_items_returned?

    @lending.reload
    assert @lending.returned_at.present?
  end

  test "all_items_returned? does not set returned_at when items still out" do
    parent_item = create(:parent_item, department: @department)
    item = create(:item, parent_item: parent_item)
    create(:line_item, lending: @lending, item: item, returned_at: nil)

    @lending.all_items_returned?

    @lending.reload
    assert_nil @lending.returned_at
  end

  # -- Validations --

  test "duration must be an integer" do
    @lending.duration = 1.5
    assert_not @lending.valid?
  end

  test "duration allows blank" do
    @lending.duration = nil
    assert @lending.valid?
  end

  test "borrower without TOS accepted is invalid" do
    borrower = create(:borrower, tos_accepted: false)
    @lending.borrower = borrower

    assert_not @lending.valid?
  end

  test "return date must be in the future when changing duration" do
    @lending.update_columns(lent_at: 30.days.ago, duration: 14)
    @lending.reload
    @lending.duration = 7

    assert_not @lending.valid?
    assert @lending.errors[:duration].any?
  end
end
