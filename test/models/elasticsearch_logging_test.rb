# ABOUTME: Tests that Elasticsearch rescue blocks log warnings when ES is unavailable
# ABOUTME: Covers 7 rescue blocks across Borrower, ParentItem, Conduct, Item, and Lending models

require "test_helper"
require "minitest/mock"

class ElasticsearchLoggingTest < ActiveSupport::TestCase
  setup do
    @warnings = []
    @stub_warn = ->(msg) { @warnings << msg }
  end

  test "Borrower.search_people logs warning when Elasticsearch is unavailable" do
    user = create(:user)
    User.current_user = user

    Borrower.stub(:search, ->(*) { raise Faraday::ConnectionFailed.new("connection refused") }) do
      Rails.logger.stub(:warn, @stub_warn) do
        result = Borrower.search_people("test query", nil, nil, nil, 1)

        assert_empty result.to_a
      end
    end

    assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
  ensure
    User.current_user = nil
  end

  test "ParentItem.search_items logs warning when Elasticsearch is unavailable" do
    user = create(:user)
    User.current_user = user

    ParentItem.stub(:search, ->(*) { raise Faraday::ConnectionFailed.new("connection refused") }) do
      Rails.logger.stub(:warn, @stub_warn) do
        result = ParentItem.search_items("test query", user.current_department_id.to_s)

        assert_empty result.to_a
      end
    end

    assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
  ensure
    User.current_user = nil
  end

  test "Conduct#reindex_borrower logs warning when Elasticsearch is unavailable" do
    conduct = create(:conduct)

    conduct.borrower.stub(:reindex, -> { raise Faraday::ConnectionFailed.new("connection refused") }) do
      Rails.logger.stub(:warn, @stub_warn) do
        conduct.send(:reindex_borrower)
      end
    end

    assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
  end

  test "Item#destroy logs warning when Elasticsearch is unavailable" do
    item = create(:item)
    parent_item = item.parent_item

    parent_item.stub(:reindex, -> { raise Faraday::ConnectionFailed.new("connection refused") }) do
      Rails.logger.stub(:warn, @stub_warn) do
        item.destroy
      end
    end

    assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
  end

  test "Item#resurrect logs warning when Elasticsearch is unavailable" do
    item = create(:item)
    item.update_column(:status, Item.statuses[:deleted])
    parent_item = item.parent_item

    parent_item.stub(:reindex, -> { raise Faraday::ConnectionFailed.new("connection refused") }) do
      Rails.logger.stub(:warn, @stub_warn) do
        item.resurrect
      end
    end

    assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
  end

  test "Item#reindex_parent_item logs warning when Elasticsearch is unavailable" do
    item = create(:item)
    parent_item = item.parent_item

    parent_item.stub(:reindex, -> { raise Faraday::ConnectionFailed.new("connection refused") }) do
      Rails.logger.stub(:warn, @stub_warn) do
        item.send(:reindex_parent_item)
      end
    end

    assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
  end

  test "Lending#finalize! logs warning when Elasticsearch is unavailable" do
    user = create(:user)
    User.current_user = user

    lending = create(:lending, :with_borrower, state: :confirmation, user: user, department: user.current_department)
    item = create(:item)
    create(:line_item, lending: lending, item: item)

    reindex_stub = -> { raise Faraday::ConnectionFailed.new("connection refused") }
    ParentItem.define_method(:reindex, reindex_stub)
    begin
      Rails.logger.stub(:warn, @stub_warn) do
        lending.send(:finalize!, {}, {"line_items" => {}})
      end

      assert @warnings.any? { |w| w.include?("Elasticsearch unavailable") && w.include?("connection refused") }
    ensure
      ParentItem.remove_method(:reindex)
    end
  ensure
    User.current_user = nil
  end
end
