# B2: Error Handling & Observability

## Problem Statement

Multiple TODOs in code for "log exception" with no implementation:

| File | Line | Issue |
|------|------|-------|
| `checkout_controller.rb` | 49 | `rescue Exception => e` with `# TODO log exception` |
| `borrowers_controller.rb` | 63, 81 | `rescue Exception => e` with `# TODO log exception` |
| `lending.rb` | 182, 194, 218, 236 | Same pattern, but inside commented-out code |

Additionally:
- No structured logging for production (Rails default verbose logging)
- Health check is minimal (just green/red HTML page at `/up`)
- Request ID tagging exists in production (`log_tags = [:request_id]`) but isn't used in error logging
- No centralized way to view logs across containers

## Goals

1. Structured JSON logging in production so logs are machine-parseable
2. Proper error handling replacing all TODO comments
3. Health check endpoints usable by Docker healthchecks
4. Log viewer (Dozzle) in Docker Compose for browsing logs across all containers
5. No external services -- everything self-contained

## Non-Goals

- External error tracking (no Sentry, no cloud logging)
- Log persistence beyond Docker's json-file retention
- APM / performance tracing
- Changing the commented-out code in `lending.rb` (those TODOs are inside
  dead code that will be rewritten in Phase C with background jobs)

## Implementation Plan

### Step 1: Structured JSON Logging with Lograge

Add Lograge to produce one JSON line per request instead of Rails' multi-line
output. This makes logs searchable in Dozzle and greppable in Docker logs.

All log output uses a single format: JSON. Lograge handles request logs,
and a JSON log formatter handles everything else (including `Rails.logger`
calls). This avoids mixed formats in log output.

**Gemfile:**
```ruby
gem 'lograge'
```

**config/environments/production.rb:**

Replace the existing log formatter and logger setup with a JSON formatter.
Remove `config.log_tags` (request_id is included in Lograge JSON output
via `append_info_to_payload` instead of as a prefix tag, which would break
JSON parsing).

```ruby
# Remove: config.log_tags = [ :request_id ]
# Remove: config.log_formatter = ::Logger::Formatter.new
# Remove: the RAILS_LOG_TO_STDOUT block

config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_options = lambda do |event|
  {
    request_id: event.payload[:request_id],
    user_id: event.payload[:user_id]
  }
end

# JSON formatter for non-Lograge log lines (background jobs, manual logs, etc.)
json_formatter = proc do |severity, timestamp, _progname, msg|
  JSON.dump(level: severity, time: timestamp.iso8601(3), msg: msg) + "\n"
end

config.logger = ActiveSupport::Logger.new(STDOUT, formatter: json_formatter)
```

**app/controllers/application_controller.rb:**
```ruby
def append_info_to_payload(payload)
  super
  payload[:request_id] = request.request_id
  payload[:user_id] = current_user&.id
end
```

This feeds `request_id` and `user_id` into Lograge's `custom_options` via
the event payload. No manual `log_tags` needed.

### Step 2: ErrorHandling Concern

Create a concern that provides structured error logging and rescue handlers.
Include it in ApplicationController.

**app/controllers/concerns/error_handling.rb:**
```ruby
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end

  private

  def log_exception(exception, level: :error)
    Rails.logger.public_send(level, {
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace&.first(10),
      request_id: request.request_id,
      user_id: current_user&.id,
      path: request.path
    })
  end

  def handle_not_found(exception)
    log_exception(exception, level: :warn)
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found, layout: "application" }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  def handle_internal_error(exception)
    log_exception(exception)
    respond_to do |format|
      format.html { render "errors/internal_server_error", status: :internal_server_error, layout: "application" }
      format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
    end
  end
end
```

Note: `log_exception` passes a hash to the logger, not a JSON string.
The JSON log formatter configured in Step 1 handles serialization, keeping
all log output in a single consistent format.

The `rescue_from` declarations are ordered so that `RecordNotFound` (more
specific) takes precedence over `StandardError` (catch-all). Rails evaluates
rescue_from in reverse declaration order.

**app/controllers/application_controller.rb:**
```ruby
class ApplicationController < ActionController::Base
  include ErrorHandling
  # ... existing code
end
```

The existing `CanCan::AccessDenied` rescue in ApplicationController stays as-is.
It already handles the redirect logic correctly and is more specific than
`StandardError`, so it takes precedence. We add `log_exception` calls where
the TODOs are.

### Step 3: Fix TODO Comments

Replace the bare `rescue Exception => e` + TODO patterns with proper logging.
Use `rescue => e` (StandardError) instead of `rescue Exception => e`.

**checkout_controller.rb line ~47:**
```ruby
begin
  LendingMailer.confirmation_email(@lending).deliver_now
rescue => e
  log_exception(e)
end
```

**borrowers_controller.rb line ~61 (add_conduct):**
```ruby
begin
  LenderMailer.ban_notification_email(@conduct).deliver_now
rescue => e
  log_exception(e)
end
```

**borrowers_controller.rb line ~79 (remove_conduct):**
```ruby
begin
  LenderMailer.ban_lifted_notification_email(@conduct, current_user).deliver_now
rescue => e
  log_exception(e)
end
```

The TODOs in `lending.rb` (lines 182, 194, 218, 236) are all inside
commented-out notification methods. These will be rewritten from scratch
in Phase C (background jobs + email). Leave them as-is.

### Step 4: Health Check Endpoints

Replace the existing minimal HealthController with proper liveness/readiness
endpoints. Docker healthchecks can use the liveness endpoint.

The current HealthController has `rescue_from(Exception)` to render a colored
page. This is replaced with structured JSON endpoints. The liveness endpoint
is intentionally minimal -- if Rails can't serve it, the container is unhealthy,
which is the correct signal.

No `skip_before_action :authenticate_user!` is needed because
ApplicationController does not have a global `authenticate_user!` filter.

**app/controllers/health_controller.rb:**
```ruby
class HealthController < ApplicationController
  def liveness
    render json: { status: "ok" }
  end

  def readiness
    checks = {
      database: check_database,
      elasticsearch: check_elasticsearch
    }
    all_ok = checks.values.all? { |c| c[:status] == "ok" }

    render json: { status: all_ok ? "ok" : "degraded", checks: checks },
           status: all_ok ? :ok : :service_unavailable
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue => e
    { status: "error", message: e.message }
  end

  def check_elasticsearch
    Searchkick.client.ping
    { status: "ok" }
  rescue => e
    { status: "error", message: e.message }
  end
end
```

**config/routes.rb:**
```ruby
get "up" => "health#liveness"
get "health/liveness" => "health#liveness"
get "health/readiness" => "health#readiness"
```

**Update Dockerfile healthcheck (if present) to use `/health/liveness`.**

### Step 5: Error Pages

Create simple error views for 404 and 500. Match the existing app layout style
(German language). These are rendered within the application layout by the
ErrorHandling concern.

**app/views/errors/not_found.html.erb:**
```erb
<div class="container mt-5">
  <h1>Seite nicht gefunden</h1>
  <p>Die angeforderte Seite existiert nicht.</p>
  <%= link_to "Zurück zur Startseite", root_path, class: "btn btn-primary" %>
</div>
```

**app/views/errors/internal_server_error.html.erb:**
```erb
<div class="container mt-5">
  <h1>Ein Fehler ist aufgetreten</h1>
  <p>Es ist ein unerwarteter Fehler aufgetreten. Bitte versuche es später erneut.</p>
  <%= link_to "Zurück zur Startseite", root_path, class: "btn btn-primary" %>
</div>
```

### Step 6: Dozzle Log Viewer

Add Dozzle to docker-compose.override.yml (development only). It reads
Docker logs via the socket -- zero changes to the Rails app.

**docker-compose.override.yml** (add to services):
```yaml
  dozzle:
    image: amir20/dozzle:v10.0.1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "9999:8080"
```

Dozzle will be available at http://localhost:9999 in development.

For production, Dozzle can optionally be added to docker-compose.yml behind
Caddy with basic auth, but this is not required initially. Docker CLI
(`docker compose logs`) remains available on the server.

## Files to Create

| File | Purpose |
|------|---------|
| `app/controllers/concerns/error_handling.rb` | Structured error logging and rescue handlers |
| `app/views/errors/not_found.html.erb` | 404 page |
| `app/views/errors/internal_server_error.html.erb` | 500 page |

## Files to Modify

| File | Change |
|------|--------|
| `Gemfile` | Add `lograge` |
| `config/environments/production.rb` | Configure lograge |
| `app/controllers/application_controller.rb` | Include ErrorHandling, add `append_info_to_payload` |
| `app/controllers/checkout_controller.rb` | Replace TODO at line 49 with `log_exception` |
| `app/controllers/borrowers_controller.rb` | Replace TODOs at lines 63, 81 with `log_exception` |
| `app/controllers/health_controller.rb` | Replace with liveness/readiness endpoints |
| `config/routes.rb` | Add health check routes |
| `docker-compose.override.yml` | Add Dozzle service |

## Testing

Tests to write (TDD):

1. **HealthController tests:**
   - `GET /health/liveness` returns 200 with `{"status": "ok"}`
   - `GET /health/readiness` returns 200 with database and elasticsearch checks
   - `GET /up` returns 200 (backwards compatibility)

2. **ErrorHandling tests:**
   - Visiting a nonexistent record returns 404
   - 404 response renders the not_found template
   - Unhandled exception returns 500
   - 500 response renders the internal_server_error template
   - `log_exception` writes structured output to the Rails logger

3. **Existing test suite** must remain green after all changes.

## Verification

- [ ] `bundle exec rails test` passes
- [ ] App boots in Docker Compose without errors
- [ ] Dozzle accessible at localhost:9999 showing logs from all containers
- [ ] `/health/liveness` returns JSON 200
- [ ] `/health/readiness` returns JSON 200 with service checks
- [ ] Trigger a mail delivery failure and confirm structured error appears in logs
- [ ] Lograge produces single-line JSON per request in production mode
