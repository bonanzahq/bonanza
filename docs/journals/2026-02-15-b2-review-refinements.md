# B2 Error Handling - Review, Refinements, and Production Testing

## Branch: feat-error-handling

## What happened

Fabian reviewed the PR manually against the running Docker stack. Several
issues surfaced and were fixed iteratively.

### Health endpoint redesign

Started with two endpoints: `/health/liveness` (Docker healthcheck) and
`/health/readiness` (DB + ES checks). Fabian questioned why we need both.
Dropped liveness, kept only readiness. Then discovered that readiness
returning 503 when ES is down marks the container as unhealthy -- Docker
would restart Rails for an ES problem. Added back a simple `GET /health`
(always returns 200) for the Docker healthcheck, kept `/health/readiness`
as a diagnostic tool.

### Error message leakage

The readiness endpoint was exposing internal error messages (hostnames,
ports) in the JSON response. Fixed: error details go to `Rails.logger.error`
only, response just shows `{"status":"error"}`.

### exceptions_app for routing errors

Visiting `/nonexistent-page` showed Rails debug page even though we have
custom German error pages. Root cause: routing errors happen at middleware
level before any controller runs, so `rescue_from` in ErrorHandling never
catches them. Fixed with `config.exceptions_app = self.routes` and an
`ErrorsController` for `/404`, `/422`, `/500` routes. Custom pages only
render in production (`consider_all_requests_local = false`). Development
keeps the useful Rails debug pages.

### CI test fix

Health controller tests assumed ES is available (expected 200 from
readiness). CI has no ES, so readiness correctly returns 503. Fixed tests
to accept both 200 and 503, while still verifying response structure.

### Manual testing

Fabian built the image locally and ran in production mode to verify:
- German 404 page renders for unknown routes
- JSON 404 response works with Accept header
- Dozzle log viewer working on port 9999
- Health endpoints working through Caddy proxy

## Commits this session

- `29b905c` refactor(health): remove liveness endpoint, keep only readiness
- `adb4780` docs: update health check references after liveness removal
- `6608905` fix(health): do not expose error messages in readiness response
- `40361b5` feat(health): add GET /health for Docker healthcheck, keep readiness for diagnostics
- `f3d55a2` feat(errors): route exceptions through app via exceptions_app
- `00a3931` docs: update error handling and health check structure docs
- `c3ba760` fix(test): accept 503 from readiness endpoint when ES is unavailable

## Decisions made

- One simple `/health` for Docker healthcheck (always 200)
- `/health/readiness` for diagnostics only (200 or 503)
- Error messages never exposed in health responses
- Custom error pages production-only, development keeps debug pages
- `exceptions_app` routes middleware errors to ErrorsController

## Open

- PR #57 awaiting CI green after latest push, then merge
- Docker directory restructure plan written, bug filed (`a09b6ba`), not yet implemented
