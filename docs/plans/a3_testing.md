# Testing Infrastructure Plan

## Current State

- Rails 7.0.4.2 with Ruby 3.1.2
- `test/` directory exists with minimal structure
- One mailer test stub exists
- No test framework gems configured
- No test factories or fixtures
- CLAUDE.md mandates TDD for all new features

## Framework Choice: Minitest

Using Rails' default Minitest framework because:
- Already partially configured
- Simpler for developers new to Ruby
- Less magic, straightforward Ruby classes
- Perfectly adequate for rigorous TDD
- Smaller dependency footprint

## Required Gems

Add to Gemfile `group :development, :test`:

```ruby
# Testing framework and tools
gem 'factory_bot_rails', '~> 6.2'      # Test data factories
gem 'shoulda-matchers', '~> 5.3'      # Cleaner model test syntax
gem 'faker', '~> 3.2'                  # Realistic fake data

# System testing (already in Rails 7, but explicitly declare)
gem 'capybara', '~> 3.39'             # Browser automation for system tests
gem 'selenium-webdriver', '~> 4.10'   # WebDriver for system tests

```

## Directory Structure

```
test/
├── application_system_test_case.rb  # Base class for system tests
├── test_helper.rb                   # Global test configuration
├── factories/                       # FactoryBot factories
│   ├── users.rb
│   ├── departments.rb
│   ├── borrowers.rb
│   ├── parent_items.rb
│   ├── items.rb
│   └── lendings.rb
├── models/                          # Model unit tests
│   ├── user_test.rb
│   ├── department_test.rb
│   ├── borrower_test.rb
│   ├── parent_item_test.rb
│   ├── item_test.rb
│   ├── lending_test.rb
│   ├── line_item_test.rb
│   └── ability_test.rb
├── controllers/                     # Controller tests
│   ├── admin/
│   ├── items_controller_test.rb
│   ├── lendings_controller_test.rb
│   └── borrowers_controller_test.rb
├── integration/                     # Integration tests
│   ├── lending_workflow_test.rb
│   └── authorization_test.rb
└── system/                          # End-to-end browser tests
    ├── lending_flow_test.rb
    ├── item_management_test.rb
    └── borrower_registration_test.rb
```

## Setup Steps

### 1. Install Gems
```bash
# Add gems to Gemfile, then:
bundle install
```

### 2. Configure test_helper.rb

Update `test/test_helper.rb`:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# FactoryBot setup
require 'factory_bot_rails'

# Shoulda Matchers setup
require 'shoulda/matchers'
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

# Searchkick test mode
Searchkick.disable_callbacks

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml
  # fixtures :all

  # Use Rails transactional fixtures for clean test state
  self.use_transactional_tests = true

  setup do
    # Set current user for thread-local tracking
    User.current_user = nil
  end

  # Helper to sign in users for controller tests
  def sign_in(user)
    user.update(current_department_id: user.departments.first&.id)
    User.current_user = user
    @current_user = user
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

### 3. Configure Searchkick for Tests

Add to `config/environments/test.rb`:

```ruby
# Searchkick test mode - don't talk to Elasticsearch
Searchkick.disable_callbacks = true
```

### 4. Create application_system_test_case.rb

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def sign_in_as(user)
    visit new_user_session_path
    fill_in "E-Mail", with: user.email
    fill_in "Passwort", with: "password123"
    click_button "Anmelden"
  end
end
```

## Testing Patterns for Bonanza Redux

### Model Tests Priority

Test in this order (highest business value first):

1. **Item** - status changes, soft delete, validation rules, lent state
2. **Lending** - state machine, workflow transitions
3. **Borrower** - registration validation, email confirmation
4. **ParentItem** - item relationships, search
5. **User** - department memberships, role logic
6. **Ability** - authorization rules per role

### Critical Test Cases

#### Item Model
- Cannot edit/delete when lent
- Soft delete creates `deleted` status instead of destroying
- History records created on save
- Status transitions (available → lent → returned)
- Condition validation

#### Lending Model
- State machine: cart → borrower → confirmation → completed
- Cannot complete without borrower
- Line items are properly associated
- `lent_at` timestamp set on completion
- Return process works correctly

#### Borrower Model
- Registration requires TOS, insurance check, ID check (students only)
- Email confirmation flow
- Soft delete via `borrower_type: :deleted`

#### Ability Model (CanCanCan)
- Admin: full access all departments
- Leader: manage users/borrowers/items/lendings in own department, send invitations
- Member: manage borrowers/items/lendings in own department
- Guest: read-only own department
- Hidden: like guest, only visible to admins
- Scoping to `current_department_id`

### Factory Examples

#### User Factory
```ruby
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }

    trait :admin do
      after(:create) do |user, evaluator|
        create(:department_membership, user: user, role: :admin)
      end
    end

    trait :leader do
      after(:create) do |user, evaluator|
        dept = create(:department)
        create(:department_membership, user: user, department: dept, role: :leader)
        user.update(current_department_id: dept.id)
      end
    end
  end
end
```

#### Item Factory
```ruby
FactoryBot.define do
  factory :item do
    association :parent_item
    association :department
    amount { 1 }
    status { :available }
    condition { :flawless }

    trait :lent do
      status { :lent }
    end

    trait :broken do
      condition { :broken }
    end
  end
end
```

### System Test Example: Complete Lending Flow

```ruby
require "application_system_test_case"

class LendingFlowTest < ApplicationSystemTestCase
  test "complete lending workflow from cart to checkout" do
    user = create(:user, :leader)
    department = user.departments.first
    parent_item = create(:parent_item, department: department)
    item = create(:item, parent_item: parent_item, department: department)
    borrower = create(:borrower, department: department)

    sign_in_as(user)

    # Add item to cart
    visit root_path
    fill_in "search-items", with: parent_item.name
    click_on parent_item.name

    # Select borrower
    fill_in "search-borrower", with: borrower.email
    click_on borrower.full_name

    # Confirm and complete
    click_button "Bestätigen"

    assert_text "Ausleihe erfolgreich"
    assert_equal :completed, Lending.last.state.to_sym
  end
end
```

## Running Tests

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/item_test.rb

# Run specific test at line number
rails test test/models/item_test.rb:12

# Run all model tests
rails test test/models

# Run system tests only
rails test:system

# Run with verbose output
rails test -v

# Run in parallel (default in Rails 7)
rails test --parallel
```

## Test Database Management

```bash
# Prepare test database (after migrations)
rails db:test:prepare

# Reset test database
rails db:test:reset

# Load schema into test database
rails db:schema:load RAILS_ENV=test
```

## Implementation Order

### Phase 1: Foundation (Week 1)
1. Add gems and run bundle install
2. Configure test_helper.rb
3. Create application_system_test_case.rb
4. Write factories for core models (User, Department, Borrower, ParentItem, Item, Lending)
5. Write first simple model test to verify setup

### Phase 2: Model Tests (Week 2-3)
1. Item model tests (status, soft delete, validations)
2. Lending model tests (state machine)
3. Borrower model tests (registration, validation)
4. User model tests (department memberships)
5. Ability tests (authorization per role)
6. ParentItem model tests

### Phase 3: Controller Tests (Week 4)
1. LendingsController (cart flow, state transitions)
2. ItemsController (CRUD, authorization)
3. BorrowersController (registration, CRUD)
4. Admin controllers

### Phase 4: Integration/System Tests (Week 5)
1. Complete lending workflow system test
2. Borrower registration and email confirmation
3. Item management flows
4. Authorization enforcement across workflows

## Test Coverage Goals

- **Models**: 100% coverage on business logic, validations, callbacks
- **Controllers**: Cover happy paths and authorization checks
- **System tests**: Cover critical user workflows (lending, returns, registration)

Don't aim for 100% coverage everywhere - focus on business-critical paths and complex logic.

## Elasticsearch Testing Strategy

For tests that need search:

```ruby
# In specific test files where search is needed
class ParentItemSearchTest < ActiveSupport::TestCase
  setup do
    # Re-enable callbacks for this test
    Searchkick.enable_callbacks
    ParentItem.reindex
    Borrower.reindex
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

Avoid testing Elasticsearch in most tests - it's slow and most logic doesn't require it.

## CI/CD Considerations

For future GitHub Actions or similar:

```yaml
# .github/workflows/test.yml
- name: Run tests
  env:
    RAILS_ENV: test
    DATABASE_URL: postgresql://postgres:postgres@localhost:5432/bonanza_test
  run: |
    bundle exec rails db:schema:load
    bundle exec rails test
```

Elasticsearch not required in CI for most tests due to disabled callbacks.

## Next Steps

1. Review this plan with Fabian
2. Add gems to Gemfile
3. Configure test environment
4. Create first factory
5. Write first test following TDD workflow
6. Iterate and expand coverage
