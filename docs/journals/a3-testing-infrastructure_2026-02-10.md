# Journal: a3-testing-infrastructure 2026-02-10

## Session Summary

Set up Phase 1 (Foundation) of the testing infrastructure plan (a3). All config files, factories, and smoke tests are written. Blocked on running tests because Docker can't start inside the VM (nested virtualization issue).

## What Was Done

### 1. Gems Added to Gemfile

Added to `:development, :test` group:
- `factory_bot_rails ~> 6.2`
- `faker ~> 3.2`

Added to `:test` group:
- `capybara ~> 3.39`
- `selenium-webdriver ~> 4.10`

Skipped `shoulda-matchers` (agreed with Fabian -- marginal value for this project).

`bundle install` completed successfully.

### 2. test/test_helper.rb

- FactoryBot syntax methods included
- Parallel test workers enabled
- Transactional tests enabled
- Searchkick callbacks disabled per-test in setup block
- Devise::Test::IntegrationHelpers included for integration tests
- User.current_user cleared in setup

### 3. test/application_system_test_case.rb

- Headless Chrome via Selenium
- `sign_in_as` helper that fills in the German-language Devise login form

### 4. Factories Created (test/factories/)

All factories based on actual model code and schema.rb (not copied from the plan):

- **departments.rb** -- sequenced name, staffed by default
- **users.rb** -- builds department_membership in after(:build) to satisfy validation; transient `role` and `department` attributes; traits: `:admin`, `:leader`, `:guest`
- **borrowers.rb** -- defaults to student with insurance_checked/id_checked set; traits: `:employee`, `:with_tos`
- **parent_items.rb** -- sequenced name, associated department
- **items.rb** -- associated parent_item, defaults to available/flawless; traits: `:lent`, `:broken`
- **lendings.rb** -- associated user and department, defaults to cart state; traits: `:with_borrower`, `:completed`
- **line_items.rb** -- associated item and lending

### 5. Smoke Tests

- `test/models/department_test.rb` -- factory creates valid department
- `test/models/user_test.rb` -- factory creates user with membership, leader/admin traits work

### 6. database.yml Updated

Test section now reads host/port/user/password from environment variables with Docker-friendly defaults:
- `TEST_DATABASE_HOST` (default: localhost)
- `TEST_DATABASE_PORT` (default: 5432)
- `TEST_DATABASE_USER` (default: postgres)
- `TEST_DATABASE_PASSWORD` (default: postgres)

### 7. Searchkick Test Configuration

Investigated the actual Searchkick 5.2.3 source code. Key findings:
- `Searchkick.disable_callbacks` is a **method call** (not `= true` assignment as the plan suggested)
- It's thread-local (`Thread.current[:searchkick_callbacks_enabled]`)
- Called in `setup` block of ActiveSupport::TestCase (inherited by forked parallel workers)
- The plan's suggestion to put `Searchkick.disable_callbacks = true` in `config/environments/test.rb` was **wrong** -- that API doesn't exist
- Item model's `reindex_parent_item` already rescues `Faraday::ConnectionFailed`, so it silently handles missing Elasticsearch

## What's Left (for next agent)

### Immediate: Run the smoke tests

On real hardware with Docker:

```bash
# 1. Start PostgreSQL container
docker run -d --name bonanza-test-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgres:15-alpine

# 2. Wait for it
until docker exec bonanza-test-db pg_isready; do sleep 1; done

# 3. Create test database and load schema
cd ~/Documents/bonanzahq/bonanza/a3-testing-infrastructure
mise exec -- bin/rails db:test:prepare

# 4. Run smoke tests
mise exec -- bin/rails test test/models/
```

If tests pass, commit and move to Phase 2 (model tests).

If tests fail, likely causes:
- Factory relationship issues (User <-> Department circular callbacks)
- Searchkick still trying to reach Elasticsearch on some code path
- Missing database columns (compare factory attributes against schema.rb)

### Phase 2: Model Tests (next task)

Per the plan priority order:
1. Item model (status, soft delete, history callbacks)
2. Lending model (state machine)
3. Borrower model (registration, validation)
4. User model (department memberships, roles)
5. Ability model (CanCanCan authorization)
6. ParentItem model

### Docker and b1 Containerization

We used a standalone `docker run` for the test database -- intentionally minimal to avoid overlap with the b1 containerization plan. When b1 is implemented, the test database setup can be folded into docker-compose as a test profile.

## Technical Decisions

1. **Searchkick disabled in setup block, not globally** -- because it's thread-local and we want it per-test to work with parallel testing
2. **No shoulda-matchers** -- plain Minitest assertions are sufficient
3. **Standalone docker run for test DB** -- keeps a3 independent from b1 containerization plan
4. **database.yml uses env vars** -- works with both Docker and any other PostgreSQL setup

## Docker VM Issue

Docker Desktop 4.59.1 is installed on the VM but the engine never starts. Attempted:
- `open -a Docker` -- backend starts, shows `"state":"ready"` in logs, but no docker.sock is created at `/var/run/docker.sock`
- Restarted Docker Desktop -- same result, timed out after 5 minutes twice
- The error dialog process (`ErrorReportAPI`) runs in the GUI but can't be dismissed from CLI
- Root cause: Docker Desktop requires a Linux VM (via Apple Virtualization Framework), which can't run inside a macOS VM (nested virtualization)

Work must continue on real hardware.
