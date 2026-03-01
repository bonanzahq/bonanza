# ABOUTME: Tests for Link model validations and callbacks.
# ABOUTME: Covers url presence, protocol auto-prepend, and parent_item association.

require "test_helper"

class LinkTest < ActiveSupport::TestCase
  setup do
    @parent_item = create(:parent_item)
  end

  test "factory creates a valid link" do
    link = create(:link, parent_item: @parent_item)
    assert link.persisted?
  end

  test "valid with url and blank title" do
    link = build(:link, parent_item: @parent_item, title: "")
    assert link.valid?
  end

  test "invalid without url" do
    link = build(:link, parent_item: @parent_item, url: nil)
    assert_not link.valid?
    assert_includes link.errors[:url], "muss ausgefüllt werden"
  end

  test "invalid without parent_item" do
    link = build(:link, parent_item: nil)
    assert_not link.valid?
  end

  test "prepends http:// when url has no scheme" do
    link = build(:link, parent_item: @parent_item, url: "example.com")
    link.valid?
    assert_equal "http://example.com", link.url
  end

  test "does not prepend when url has http://" do
    link = build(:link, parent_item: @parent_item, url: "http://example.com")
    link.valid?
    assert_equal "http://example.com", link.url
  end

  test "does not prepend when url has https://" do
    link = build(:link, parent_item: @parent_item, url: "https://example.com")
    link.valid?
    assert_equal "https://example.com", link.url
  end

  test "does not modify blank url" do
    link = build(:link, parent_item: @parent_item, url: "")
    link.valid?
    assert_equal "", link.url
  end
end
