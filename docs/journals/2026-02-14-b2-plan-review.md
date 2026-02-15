# B2 Error Handling Plan Review

## What happened

Reviewed the b2_error-handling.md plan with Fabian, focusing on the Dozzle
log viewer setup and the overall error handling approach. Identified six
issues and updated the plan to address them.

## Changes to the plan

1. **Single JSON log format**: Replaced the mixed-format approach (Lograge
   JSON for requests + `Logger::Formatter` text for everything else) with a
   unified JSON setup. Added a JSON proc formatter for the Rails logger so
   all output (Lograge request logs, manual Rails.logger calls, exception
   logs) is JSON. Removed `log_tags = [:request_id]` since tagged logging
   prepends text that breaks JSON parsing; request_id is now injected via
   `append_info_to_payload` into Lograge's JSON payload instead.

2. **`log_exception` passes hash, not JSON string**: The method now passes a
   Ruby hash to the logger and lets the formatter handle serialization.
   Previously it called `.to_json` manually, producing JSON-inside-text.

3. **Explicit `rescue_from StandardError`**: Added `handle_internal_error` to
   the ErrorHandling concern as a catch-all for unhandled exceptions. Returns
   500 with a German error page. `RecordNotFound` and `CanCan::AccessDenied`
   are more specific and take precedence.

4. **Added 500 error template**: `internal_server_error.html.erb` with German
   text, matching the 404 pattern.

5. **Removed unnecessary `skip_before_action :authenticate_user!`**: Verified
   that ApplicationController has no global `authenticate_user!` filter, so
   the skip was dead code.

6. **Pinned Dozzle to v10.0.1**: Was `:latest`, now pinned for reproducibility.

## Decisions

- Liveness endpoint intentionally has no catch-all rescue. If Rails can't
  serve it, the container is unhealthy -- that's the correct signal.
- `CanCan::AccessDenied` rescue stays in ApplicationController as-is. It
  has specific redirect logic that should not be generalized.
- Commented-out TODOs in `lending.rb` are left alone (dead code, rewritten
  in Phase C).

## Next steps

- Execute b2: implement the plan (git-bug 9b6a588 is open)
