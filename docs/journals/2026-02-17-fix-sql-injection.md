# Fix SQL Injection in Weekly Lending Activity Query

Branch: `fix-sql-injection`
PR: https://github.com/bonanzahq/bonanza/pull/115
git-bug: ec6153b (closed)

## Summary

Fixed a SQL injection vulnerability in `ParentItemsController#get_weekly_lending_activity`
where `date_begin`, `date_end`, and `parent_item_id` were interpolated directly into raw
SQL via Ruby string interpolation (`#{var}`).

## What changed

- **`app/controllers/parent_items_controller.rb`**: Replaced string interpolation with
  `ActiveRecord::Base.sanitize_sql_array` using `?` placeholders for all three dynamic
  values in the `generate_series` and `WHERE` clauses.
- **`test/controllers/parent_items_controller_test.rb`**: Added integration tests for the
  `show` action covering authentication redirect, empty activity data, and populated
  lending activity with real DB records.

## Testing

- TDD approach: wrote controller tests first, confirmed they pass, applied fix, confirmed
  tests still pass.
- Full test suite: 269 tests, 0 failures.
- E2E via Docker Compose + browser: logged in as admin, visited multiple parent item detail
  pages (`/artikel/1`, `/artikel/2`), confirmed the Ausleihstatistik chart renders correctly.
  No SQL errors in Rails logs.
- Manual verification by Fabian confirmed the fix works.

## Technical notes

- The test database for unit tests ran on a dedicated container (`bonanza-sqli-test-db`)
  on port 5433 to avoid conflicts with other agents' worktrees.
- `sanitize_sql_array` quotes Date objects via `.to_s` producing `YYYY-MM-DD` format,
  which PostgreSQL's `::date` cast handles correctly. Same behavior as the old string
  interpolation, but safe against injection.
- `docker compose exec rails bundle exec rails runner` fails in this setup because the
  container runs `RAILS_ENV=production` but `runner` defaults to development. Must pass
  `RAILS_ENV=production` explicitly or use `bash -c`.
