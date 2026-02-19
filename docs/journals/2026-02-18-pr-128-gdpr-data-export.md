# PR #128: GDPR Data Export

Branch: `feat/gdpr-data-export`
PR: https://github.com/bonanzahq/bonanza/pull/128
Status: Open

## Summary

Exposes the `Borrower#export_personal_data` and `Borrower#request_deletion!` model methods through two new controller actions and routes. Staff with `:read` ability can download a borrower's personal data as a JSON file via `GET /verwaltung/:id/export_data`; staff with `:destroy` ability can trigger deletion or anonymisation via `POST /verwaltung/:id/request_deletion`. The borrower detail partial gains two action buttons for these operations.

## What changed

| File | Change |
|------|--------|
| `app/controllers/borrowers_controller.rb` | Added `export_data` action (sends JSON file via `send_data`; requires `:read` ability); added `request_deletion` action (calls `request_deletion!`, redirects with notice on `:anonymized`/`:deleted`, rescues `ActiveRecord::RecordNotDestroyed` with alert); both actions added to `set_borrower` `before_action` |
| `app/views/borrowers/_borrower.html.erb` | Adds "Daten exportieren" link (`export_data_borrower_path`) and "Daten loeschen" button (`request_deletion_borrower_path`, POST with Turbo confirm dialog) inside the `can? :manage, borrower` block |
| `config/routes.rb` | Adds `member` routes inside `resources :borrowers`: `get :export_data` and `post :request_deletion` |
| `test/controllers/borrowers_gdpr_test.rb` | New — 4 integration tests |

## Why

PR #126 implemented the GDPR model methods but left no way to invoke them from the application. This PR completes the feature by adding the HTTP endpoints and UI controls so staff can fulfil subject-access and erasure requests directly from a borrower's detail page.

## Test coverage

| Test file | Tests | What they verify |
|-----------|-------|-----------------|
| `test/controllers/borrowers_gdpr_test.rb` | `export_data requires authentication` | Unauthenticated GET redirects to `new_user_session_path` |
| | `export_data returns JSON file` | Authenticated GET responds 200 with `content_type == "application/json"` |
| | `request_deletion requires authentication` | Unauthenticated POST redirects to `new_user_session_path` |
| | `request_deletion anonymizes borrower without active lendings` | POST with a returned lending anonymizes borrower and redirects to `borrowers_url` |
| | `request_deletion fails for borrower with active lending` | POST with an unreturned line item redirects back to the borrower page without anonymizing |

## Manual verification

Run the GDPR controller tests:

```bash
docker compose exec rails bundle exec rails test test/controllers/borrowers_gdpr_test.rb
```

Verify the export route is registered:

```bash
docker compose exec rails bundle exec rails routes | grep export_data
```

Export a borrower's data via the UI by navigating to `/verwaltung/:id` and clicking "Daten exportieren". The browser should download a `.json` file named `borrower-data-<id>-<date>.json`.

Test the deletion request via the UI by clicking "Daten loeschen" and confirming the dialog. Observe the flash message:
- "Die personenbezogenen Daten wurden anonymisiert." if the borrower has recent lending history
- "Der Datensatz wurde vollstaendig geloescht." if no lendings exist

Test the active-lending guard from the console:

```bash
docker compose exec rails bundle exec rails console
# In the console:
b = Borrower.joins(:lendings).where(lendings: { returned_at: nil }).first
b.request_deletion!   # => raises ActiveRecord::RecordNotDestroyed
```
