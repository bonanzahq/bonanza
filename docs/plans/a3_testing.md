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

### Phase 3: Controller Tests -- NEXT

Controller tests use `ActionDispatch::IntegrationTest` with Devise test helpers.
Each test file covers: authentication, authorization (CanCanCan), happy paths,
error paths, and parameter handling.

Priority order (by business value and complexity):

1. **LendingController** -- the core workflow
   - Unauthenticated access redirects to sign-in
   - `populate` adds items to cart, rejects invalid (wrong department, unavailable, exceeds stock)
   - `remove_line_item` removes from cart
   - `update` modifies cart quantities
   - `empty` clears cart
   - `destroy` deletes lending and restores item availability
   - `show` with token works without authentication (public lending receipt)
   - Search fallback when Elasticsearch is down

2. **CheckoutController** -- state machine advancement
   - Before-action guards: requires line items, staffed department, valid state
   - `update` advances state (cart -> borrower -> confirmation -> completed)
   - Borrower assignment and TOS validation
   - Completion sets `lent_at`, decreases item quantities
   - Authorization: only lending owner or admin can checkout

3. **ReturnsController** -- item return workflow
   - `index` groups returns by due date, shows overdue
   - `take_back` marks line items returned, restores quantities
   - Authorization: scoped to user's department

4. **BorrowersController** -- CRUD + self-registration
   - Standard CRUD with authorization
   - `self_register`/`self_create` -- public registration flow
   - `confirm_email` -- email confirmation with token
   - `add_conduct`/`remove_conduct` -- ban/warn management
   - Search with pagination and status filters

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

1. Complete lending workflow (cart -> checkout -> return)
2. Borrower self-registration and email confirmation
3. Item management (create parent item, add items, lend, return)
4. Authorization enforcement across workflows (role-based access)

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
