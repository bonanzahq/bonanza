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

  # -- URL format validation --

  test "valid with standard domain url" do
    link = build(:link, parent_item: @parent_item, url: "https://example.com")
    assert link.valid?
  end

  test "valid with url containing path" do
    link = build(:link, parent_item: @parent_item, url: "https://example.com/docs/manual.pdf")
    assert link.valid?
  end

  test "valid with url containing query params" do
    link = build(:link, parent_item: @parent_item, url: "https://example.com/search?q=test&page=1")
    assert link.valid?
  end

  test "valid with url containing fragment" do
    link = build(:link, parent_item: @parent_item, url: "https://example.com/page#section")
    assert link.valid?
  end

  test "valid with url containing port" do
    link = build(:link, parent_item: @parent_item, url: "https://example.com:8080/path")
    assert link.valid?
  end

  test "valid with subdomain url" do
    link = build(:link, parent_item: @parent_item, url: "https://docs.example.com")
    assert link.valid?
  end

  test "valid with domain-only input that gets http prepended" do
    link = build(:link, parent_item: @parent_item, url: "example.com")
    assert link.valid?
    assert_equal "http://example.com", link.url
  end

  test "valid with domain and path input that gets http prepended" do
    link = build(:link, parent_item: @parent_item, url: "example.com/manual.pdf")
    assert link.valid?
    assert_equal "http://example.com/manual.pdf", link.url
  end

  test "valid with hyphenated domain" do
    link = build(:link, parent_item: @parent_item, url: "https://my-site.example.com")
    assert link.valid?
  end

  test "invalid with random string" do
    link = build(:link, parent_item: @parent_item, url: "asdf")
    assert_not link.valid?
    assert link.errors[:url].any?
  end

  test "invalid with single word" do
    link = build(:link, parent_item: @parent_item, url: "foobar")
    assert_not link.valid?
    assert link.errors[:url].any?
  end

  test "invalid with spaces" do
    link = build(:link, parent_item: @parent_item, url: "not a url")
    assert_not link.valid?
    assert link.errors[:url].any?
  end

  test "invalid with just a protocol" do
    link = build(:link, parent_item: @parent_item, url: "http://")
    assert_not link.valid?
    assert link.errors[:url].any?
  end

  test "invalid with protocol and no domain dot" do
    link = build(:link, parent_item: @parent_item, url: "http://localhost")
    assert_not link.valid?
    assert link.errors[:url].any?
  end
end
