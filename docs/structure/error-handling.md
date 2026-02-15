# Error Handling & Observability

## Error Handling

### ErrorHandling Concern

`app/controllers/concerns/error_handling.rb` is included in
`ApplicationController` and provides:

- `rescue_from StandardError` -> 500 page (`errors/internal_server_error`)
- `rescue_from ActiveRecord::RecordNotFound` -> 404 page (`errors/not_found`)
- `log_exception(exception, level:)` helper for structured error logging

The `CanCan::AccessDenied` rescue in `ApplicationController` is declared
after `include ErrorHandling`, so it takes precedence (Rails processes
`rescue_from` in reverse declaration order).

### ErrorsController

`app/controllers/errors_controller.rb` handles errors routed by
`exceptions_app` (configured in `config/application.rb`). Routing errors
and other middleware-level exceptions bypass controller `rescue_from`,
so Rails routes them to `/404` or `/500` which map to this controller.

In development, `consider_all_requests_local = true` shows Rails debug
pages instead. The custom error pages render in production only.

### Error Pages

- `app/views/errors/not_found.html.erb` -- German 404 page
- `app/views/errors/internal_server_error.html.erb` -- German 500 page

Both render within the application layout.

### Exception Logging in Controllers

Mailer delivery calls in `CheckoutController` and `BorrowersController`
are wrapped in `rescue => e` blocks that call `log_exception(e)`. This
ensures mail failures don't crash the request but are still logged.

## Structured Logging (Production)

Lograge replaces Rails' multi-line request logs with single-line JSON.
Configuration is in `config/environments/production.rb`.

- Lograge outputs JSON request logs with `request_id` and `user_id`
- A JSON proc formatter on the Rails logger ensures non-Lograge log lines
  (background jobs, `Rails.logger` calls) are also JSON
- `append_info_to_payload` in `ApplicationController` injects `request_id`
  and `user_id` into the Lograge event payload

## Health Checks

`HealthController` provides two endpoints:

| Route | Purpose |
|-------|---------|
| `GET /health` | Returns `{"status": "ok"}`. Used by Docker healthcheck. |
| `GET /health/readiness` | Checks database and Elasticsearch connectivity. Returns `{"status": "ok"}` or `{"status": "degraded"}` with per-check details. For diagnostics only. Error messages are logged but not exposed in the response. |

## Log Viewer (Development)

Dozzle runs in `docker-compose.override.yml` on port 9999. It reads container
logs via the Docker socket (read-only). Available at `http://localhost:9999`
during development.
