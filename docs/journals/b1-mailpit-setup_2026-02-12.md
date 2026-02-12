# B1 ActionMailer + Mailpit Setup

## What was done

Wired ActionMailer to deliver via SMTP to the Mailpit container so emails
actually work in the Docker development environment.

### ActionMailer configuration

- Set `delivery_method: :smtp` in `development.rb` with `SMTP_HOST` / `SMTP_PORT`
  env vars (defaults to `localhost:1025` for non-Docker use)
- Changed `raise_delivery_errors` to `true` so mail failures surface instead
  of being silently swallowed
- Added `SMTP_HOST=mailpit` and `SMTP_PORT=1025` to the rails service in
  `docker-compose.yml`

### Email URL fix

- `default_url_options` was hardcoded to `localhost:3000`, so email links
  pointed to the Rails port instead of the Caddy proxy
- Made configurable via `APP_HOST` / `APP_PORT` env vars
- Set to `localhost:8080` in docker-compose.yml (Caddy port)
- For Tailscale access, override `APP_HOST` in compose or an override file

## Verification

- Generic `ActionMailer::Base.mail` delivers to Mailpit
- `BorrowerMailer.confirm_email` delivers the real registration confirmation
  email to Mailpit with correct from address (`bonanza@fh-potsdam.de`)
- All email links point to `localhost:8080` (Caddy) not `localhost:3000`
- Fabian confirmed confirmation link works via Tailscale on :8080

## Bugs filed (not fixed -- unrelated to containerization)

- `b1e9df2` -- BorrowersController calls nonexistent `LenderMailer` for
  ban/unban notifications (should be `BorrowerMailer`)
- `476b3b2` -- CheckoutController calls nonexistent
  `LendingMailer.confirmation_email` (class exists but is empty)

## Commits

- `8e6ba25` feat: configure ActionMailer to deliver via Mailpit in development
- `f91d78d` fix: make email URLs configurable via APP_HOST/APP_PORT

## For next session

ActionMailer bug (cc7f2a6 / #44) can be closed -- the core issue (no SMTP
config) is fixed. The nil `email_token` workaround guards in views can stay
until the broken `LenderMailer` references (b1e9df2) are also fixed.

Remaining containerization work unchanged from previous journal entry.
