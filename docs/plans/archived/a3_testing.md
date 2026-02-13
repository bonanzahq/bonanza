# Testing Infrastructure Plan

## Framework Choice: Minitest

Using Rails' default Minitest framework because:
- Already partially configured
- Simpler for developers new to Ruby
- Less magic, straightforward Ruby classes
- Perfectly adequate for rigorous TDD
- Smaller dependency footprint

## Gems

In Gemfile `group :development, :test`:

```ruby
gem 'factory_bot_rails'
gem 'faker'
gem 'capybara'
gem 'selenium-webdriver'
```

## Directory Structure

```
test/
├── test_helper.rb                   # Global test configuration
├── application_system_test_case.rb  # Base class for system tests
├── factories/                       # FactoryBot factories
│   ├── borrowers.rb
│   ├── conducts.rb
│   ├── departments.rb
│   ├── items.rb
│   ├── lendings.rb
│   ├── line_items.rb
│   ├── parent_items.rb
│   └── users.rb
├── models/                          # Model unit tests
│   ├── ability_test.rb
│   ├── borrower_test.rb
│   ├── conduct_test.rb
│   ├── department_test.rb
│   ├── item_test.rb
│   ├── lending_test.rb
│   ├── line_item_test.rb
│   ├── parent_item_test.rb
│   └── user_test.rb
├── controllers/                     # Controller tests
│   ├── lending_controller_test.rb
│   ├── checkout_controller_test.rb
│   ├── returns_controller_test.rb
│   ├── borrowers_controller_test.rb
│   ├── parent_items_controller_test.rb
│   ├── departments_controller_test.rb
│   ├── users_controller_test.rb
│   ├── autocomplete_controller_test.rb
│   ├── health_controller_test.rb
│   └── static_pages_controller_test.rb
├── integration/                     # Integration tests
│   ├── lending_workflow_test.rb
│   └── authorization_test.rb
└── system/                          # End-to-end browser tests
    ├── lending_flow_test.rb
    ├── item_management_test.rb
    └── borrower_registration_test.rb
```

## Running Tests

```bash
bin/test                              # Reproducible test runner script
rails test                            # Run all tests
rails test test/models                # Run all model tests
rails test test/models/item_test.rb   # Run specific file
rails test test/models/item_test.rb:12 # Run specific test at line
rails test:system                     # System tests only
```

## Implementation Order

### Phase 1: Foundation -- DONE

1. ~~Add gems and run bundle install~~
2. ~~Configure test_helper.rb (FactoryBot, Devise helpers, Searchkick disabled)~~
3. ~~Create bin/test script for reproducible test runs~~
4. ~~Write factories for core models~~
5. ~~Write smoke tests for Department and User to verify setup~~

### Phase 2: Model Tests -- DONE

9 model test files covering:

1. ~~Item (enums, validations, lent protection, soft/hard delete, resurrect, history tracking, user_adjusted_quantity)~~
2. ~~Lending (enums, token, state machine, overdue, has_line_items, scopes, populate with all guards, all_items_returned, validations)~~
3. ~~Borrower (enums, validations, student/employee paths, email/student_id uniqueness, TOS context, fullname, soft delete, conduct queries)~~
4. ~~User (validations, fullname, role queries, current_role, role_in, is_guest_everywhere, ensure_current_department, thread-local current_user)~~
5. ~~Ability (admin, leader, member, guest, unauthenticated -- department-scoped permissions)~~
6. ~~ParentItem (factory, has_lent_items, dependent destroy, item ordering)~~
7. ~~LineItem (validations, decrease_item_quantity, apply_line_item_data_to_item, take_back with edge cases)~~
8. ~~Department (genus enum, staffed setter, get_all_visible_ids, genderize, auto-membership callback)~~
9. ~~Conduct (kind enum, validations, duration_or_perma custom validation)~~

Known gaps (tracked as issues or TODOs):
- Hidden role not tested in user_test or ability_test
- Role query exclusivity (guest? true implies member? false, etc.)
- `current_role=` setter is broken (git-bug filed)
- Lending methods `eradicate`, `update_cart`, `update_from_checkout_params` untested at model level

### Phase 3: Controller Tests (Core) -- DONE

57 tests covering four controllers:

1. ~~**ReturnsController** (9 tests) -- index auth/rendering, take_back, guest access~~
2. ~~**LendingController** (19 tests) -- index, show (public/auth), populate, remove, empty, destroy, change_duration~~
3. ~~**CheckoutController** (10 tests) -- before-action guards, state machine, update completion~~
4. ~~**BorrowersController** (19 tests) -- CRUD, conduct, self-registration, email confirmation~~

Bugs fixed during Phase 3:
- `lending_route` -> `lending_path`, `cart_path` -> `lending_path`
- `errors.values` -> `errors.full_messages` (Rails 6.1 removal)
- Double render in show/show_printable_agreement (missing `and return`)
- Missing `token:` in change_duration error redirect
- Searchkick 5.x lazy evaluation in fallback rescue
- Added mailer `default_url_options` for test environment

Known issues filed as git-bug:
- `ensure_lending_not_completed` bypassed by in-memory state mutation
- `add_conduct` crashes due to `lending_id NOT NULL` / `optional: true` mismatch

### Phase 3b: Controller Tests (Remaining) -- NEXT

5. **ParentItemsController** -- equipment type management
   - CRUD with department-scoped authorization
   - File attachment and removal
   - Nested items and accessories
   - Tagging

6. **UsersController** -- user management
   - CRUD with role-based authorization (leaders can't edit admins)
   - Nested department membership management
   - Password handling (blank password in update = no change)

7. **DepartmentsController** -- department management
   - Public index (no auth required)
   - CRUD for admins/leaders
   - `staff`/`unstaff` toggle

8. **AutocompleteController** -- JSON search endpoints
   - `items` returns parent item names scoped to department
   - `borrowers` returns borrower names (excludes deleted)
   - Requires authentication

9. **HealthController** -- simple smoke test
   - Returns 200 when app is up
   - No authentication required

10. **StaticPagesController** -- public pages + legal text admin
    - Public pages render without auth
    - Legal text editing requires admin

### Phase 4: Integration/System Tests

After controller tests are solid:

## Implementation Order

### Phase 1: Foundation
1. Add gems and run bundle install
2. Configure test_helper.rb
3. Create application_system_test_case.rb
4. Write factories for core models (User, Department, Borrower, ParentItem, Item, Lending)
5. Write first simple model test to verify setup

### Phase 2: Model Tests
1. Item model tests (status, soft delete, validations)
2. Lending model tests (state machine)
3. Borrower model tests (registration, validation)
4. User model tests (department memberships)
5. Ability tests (authorization per role)
6. ParentItem model tests

### Phase 3: Controller Tests
1. LendingsController (cart flow, state transitions)
2. ItemsController (CRUD, authorization)
3. BorrowersController (registration, CRUD)
4. Admin controllers

### Phase 4: Integration/System Tests
1. Complete lending workflow system test
2. Borrower registration and email confirmation
3. Item management flows
4. Authorization enforcement across workflows

## Test Coverage Goals

- **Models**: 100% coverage on business logic, validations, callbacks
- **Controllers**: Happy paths, error paths, and authorization checks
- **System tests**: Critical user workflows (lending, returns, registration)

Focus on business-critical paths and complex logic over raw coverage numbers.

## Elasticsearch Testing Strategy

Most tests run with `Searchkick.disable_callbacks` (set in test_helper.rb).
For tests that need search, re-enable per test:

```ruby
class ParentItemSearchTest < ActiveSupport::TestCase
  setup do
    Searchkick.enable_callbacks
    ParentItem.reindex
  end

  teardown do
    Searchkick.disable_callbacks
  end

  test "search finds items by name" do
    parent_item = create(:parent_item, name: "Camera Sony A7")
    ParentItem.search_index.refresh

    results = ParentItem.search_items("Sony", department_id: parent_item.department_id)
    assert_includes results, parent_item
  end
end
```
