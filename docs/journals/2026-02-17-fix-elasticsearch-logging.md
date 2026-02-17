# fix-elasticsearch-logging

## Task

Add `Rails.logger.warn` to 7 silent Elasticsearch rescue blocks across 5 model files so connection failures become observable in production logs while preserving graceful degradation.

## What was done

- Wrote 7 tests first (TDD), one per rescue block, using `Rails.logger.stub(:warn, ...)` to capture warnings
- Added `=> e` and `Rails.logger.warn("Elasticsearch unavailable: #{e.message}")` to all 7 rescue blocks
- All 7 new tests pass; 2 pre-existing controller test failures unrelated (ES not running)
- Opened PR #106 targeting main, closed git-bug fe2ca01

## Files changed

- `test/models/elasticsearch_logging_test.rb` (new)
- `app/models/borrower.rb` - search_people
- `app/models/parent_item.rb` - search_items
- `app/models/conduct.rb` - reindex_borrower
- `app/models/item.rb` - destroy, resurrect, reindex_parent_item (3 blocks)
- `app/models/lending.rb` - finalize!

## Technical notes

- `minitest/mock` must be required explicitly for `Object#stub` to work on model instances
- Lending#finalize! is private and takes 2 args (params, accessory_options). The accessory_options hash must include `{"line_items" => {}}` or it raises NoMethodError on nil when accessing `.keys`
- For Lending test, stubbing a specific ParentItem instance doesn't work because `line_items.each` reloads from DB, creating new Ruby objects. Used `ParentItem.define_method(:reindex, ...)` to stub at class level instead
- Searchkick callbacks are disabled in test_helper, so after_commit reindex callbacks don't fire automatically. Tests call private methods directly with `send(:method_name)`
- The 2 controller test failures (BorrowersController, LendingController returning 500) are pre-existing and documented in AGENTS.md - they happen when ES isn't running
