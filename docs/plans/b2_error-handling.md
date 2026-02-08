# Error Handling & Observability Plan

## Problem Statement

Multiple TODOs in code for "log exception" with no implementation:

| File | Line | Issue |
|------|------|-------|
| `checkout_controller.rb` | 49 | "TODO log exception" |
| `borrowers_controller.rb` | 63, 81 | "TODO log exception" |
| `lending.rb` | 182, 194, 218, 236 | Commented-out exception handling |

Additionally:
- No centralized error tracking
- No structured logging for production
- Health checks only return basic status
- No request ID tracking for debugging

## Solution Overview

1. Structured logging with Lograge
2. Exception tracking with Sentry
3. Comprehensive health checks
4. Request ID tracking
5. Fix all TODO comments with proper error handling

## Implementation Plan

### Phase 1: Structured Logging

**Add Lograge for JSON logging in production:**

```ruby
# Gemfile
gem 'lograge'
```

```ruby
# config/environments/production.rb
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_options = lambda do |event|
  {
    request_id: event.payload[:request_id],
    user_id: event.payload[:user_id],
    remote_ip: event.payload[:remote_ip]
  }
end
```

```ruby
# app/controllers/application_controller.rb
def append_info_to_payload(payload)
  super
  payload[:request_id] = request.request_id
  payload[:user_id] = current_user&.id
  payload[:remote_ip] = request.remote_ip
end
```

### Phase 2: Exception Tracking with Sentry

**Install Sentry:**

```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'
```

**Configure Sentry:**

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.profiles_sample_rate = 0.1

  # Filter sensitive data
  config.before_send = lambda do |event, hint|
    event.request.data = '[FILTERED]' if event.request&.data
    event
  end

  # Set environment
  config.environment = Rails.env

  # Set release version
  config.release = ENV.fetch('APP_VERSION', 'development')
end
```

**Add user context:**

```ruby
# app/controllers/application_controller.rb
before_action :set_sentry_context

private

def set_sentry_context
  Sentry.set_user(
    id: current_user&.id,
    email: current_user&.email,
    department: current_user&.current_department&.name
  )
end
```

### Phase 3: Health Checks

**Create health controller:**

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  # Liveness: Is the process running?
  # Used by Docker/Kubernetes to know if container should restart
  def liveness
    render json: { status: 'ok', timestamp: Time.current.iso8601 }
  end

  # Readiness: Can the app handle requests?
  # Used by load balancer to know if traffic should be sent
  def readiness
    checks = {
      database: check_database,
      elasticsearch: check_elasticsearch,
      migrations: check_migrations
    }

    all_ok = checks.values.all? { |v| v[:status] == 'ok' }
    status_code = all_ok ? :ok : :service_unavailable

    render json: {
      status: all_ok ? 'ok' : 'degraded',
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status_code
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok' }
  rescue => e
    { status: 'error', message: e.message }
  end

  def check_elasticsearch
    Searchkick.client.ping
    { status: 'ok' }
  rescue => e
    { status: 'error', message: e.message }
  end

  def check_migrations
    pending = ActiveRecord::Migration.check_all_pending!
    { status: 'ok' }
  rescue ActiveRecord::PendingMigrationError => e
    { status: 'error', message: 'Pending migrations' }
  rescue => e
    { status: 'ok' } # No pending migrations
  end
end
```

**Add routes:**

```ruby
# config/routes.rb
get '/health/liveness', to: 'health#liveness'
get '/health/readiness', to: 'health#readiness'
# Keep existing /up for backwards compatibility
get '/up', to: 'health#liveness'
```

### Phase 4: Request ID Tracking

**Enable request IDs:**

```ruby
# config/application.rb
config.middleware.use ActionDispatch::RequestId
config.log_tags = [:request_id]
```

**Pass to Sentry:**

```ruby
# app/controllers/application_controller.rb
before_action :set_request_context

def set_request_context
  Sentry.set_tags(request_id: request.request_id)
end
```

### Phase 5: Fix TODO Comments

**Create error handling helper:**

```ruby
# app/controllers/concerns/error_handling.rb
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    # Only catch StandardError in production to avoid swallowing bugs during development
    rescue_from StandardError, with: :handle_unexpected_error if Rails.env.production?
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from CanCan::AccessDenied, with: :handle_access_denied
  end

  private

  def handle_unexpected_error(exception)
    # Always log at error level regardless of environment
    log_error(exception)
    Sentry.capture_exception(exception)

    respond_to do |format|
      format.html { render 'errors/internal_server_error', status: :internal_server_error }
      format.json { render json: { error: 'Internal server error' }, status: :internal_server_error }
    end
  end

  def handle_not_found(exception)
    log_error(exception, level: :warn)

    respond_to do |format|
      format.html { render 'errors/not_found', status: :not_found }
      format.json { render json: { error: 'Not found' }, status: :not_found }
    end
  end

  def handle_access_denied(exception)
    log_error(exception, level: :warn)

    respond_to do |format|
      format.html { redirect_to root_path, alert: 'Zugriff verweigert.' }
      format.json { render json: { error: 'Access denied' }, status: :forbidden }
    end
  end

  def log_error(exception, level: :error)
    Rails.logger.public_send(level, {
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace&.first(10),
      request_id: request.request_id,
      user_id: current_user&.id,
      path: request.path
    }.to_json)
  end
end
```

**Include in ApplicationController:**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ErrorHandling
  # ...
end
```

**Fix specific TODOs:**

```ruby
# checkout_controller.rb - replace TODO with:
rescue => e
  log_error(e)
  Sentry.capture_exception(e)
  flash[:alert] = "Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut."
  redirect_to root_path
```

```ruby
# borrowers_controller.rb - replace TODOs with:
rescue => e
  log_error(e)
  Sentry.capture_exception(e)
  @borrower.errors.add(:base, "Ein Fehler ist aufgetreten.")
  render :new, status: :unprocessable_entity
```

### Phase 6: Error Pages

**Create error views:**

```erb
<!-- app/views/errors/internal_server_error.html.erb -->
<div class="error-page">
  <h1>Ein Fehler ist aufgetreten</h1>
  <p>Bitte versuchen Sie es später erneut.</p>
  <p class="error-id">Fehler-ID: <%= request.request_id %></p>
  <%= link_to 'Zurück zur Startseite', root_path, class: 'btn btn-primary' %>
</div>
```

```erb
<!-- app/views/errors/not_found.html.erb -->
<div class="error-page">
  <h1>Seite nicht gefunden</h1>
  <p>Die angeforderte Seite existiert nicht.</p>
  <%= link_to 'Zurück zur Startseite', root_path, class: 'btn btn-primary' %>
</div>
```

## Environment Variables

```env
# Sentry
SENTRY_DSN=https://xxx@sentry.io/xxx

# App version (set during deployment)
APP_VERSION=1.0.0
```

## Docker Integration

**Update docker-compose for log aggregation:**

```yaml
services:
  app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Deliverables

- [ ] Lograge configured for structured JSON logging
- [ ] Sentry installed and configured
- [ ] Health check endpoints created (/health/liveness, /health/readiness)
- [ ] Request ID tracking enabled
- [ ] ErrorHandling concern created
- [ ] All TODO comments replaced with proper error handling
- [ ] Error pages created
- [ ] Documentation updated

## Files to Modify

| File | Change |
|------|--------|
| `Gemfile` | Add lograge, sentry-ruby, sentry-rails |
| `config/environments/production.rb` | Configure lograge |
| `config/initializers/sentry.rb` | New file |
| `app/controllers/health_controller.rb` | New file |
| `app/controllers/concerns/error_handling.rb` | New file |
| `app/controllers/application_controller.rb` | Include ErrorHandling |
| `app/controllers/checkout_controller.rb` | Fix TODO at line 49 |
| `app/controllers/borrowers_controller.rb` | Fix TODOs at lines 63, 81 |
| `app/models/lending.rb` | Fix commented exception handling |
| `config/routes.rb` | Add health check routes |
| `app/views/errors/` | New error pages |

## Timeline

| Phase | Duration |
|-------|----------|
| Phase 1: Structured logging | 0.5 day |
| Phase 2: Sentry setup | 0.5 day |
| Phase 3: Health checks | 0.5 day |
| Phase 4: Request ID tracking | 0.25 day |
| Phase 5: Fix TODOs | 0.5 day |
| Phase 6: Error pages | 0.25 day |
| **Total** | **2-3 days** |

## Testing

```ruby
# test/controllers/health_controller_test.rb
class HealthControllerTest < ActionDispatch::IntegrationTest
  test "liveness returns ok" do
    get '/health/liveness'
    assert_response :success
    assert_equal 'ok', JSON.parse(response.body)['status']
  end

  test "readiness checks all services" do
    get '/health/readiness'
    assert_response :success
    body = JSON.parse(response.body)
    assert body['checks'].key?('database')
    assert body['checks'].key?('elasticsearch')
  end
end
```
