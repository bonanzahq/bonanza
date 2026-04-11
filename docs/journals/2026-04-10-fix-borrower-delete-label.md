# fix-borrower-delete-label

## Summary

Renamed the ambiguous "Daten löschen" button on the borrower detail page to
"Benutzerdaten löschen". Three instances updated in `_borrower.html.erb`:
trigger button, modal title, and confirm button. Added a controller test
asserting all three labels.

## Observations

- [technique] Rails 8 `button_to` renders `<button type="submit">` not
  `<input type="submit">`. Use `assert_select "button[type=submit]", text: "..."` 
  instead of `assert_select "input[type=submit][value='...']"`.
- [lesson] This worktree had no `node_modules` or compiled assets. Controller
  tests that render views need `pnpm build && pnpm build:css` first or they
  fail with "asset not present in the asset pipeline".

## Changes

- `app/views/borrowers/_borrower.html.erb` — 3 label replacements
- `test/controllers/borrowers_controller_test.rb` — 1 new test

## Artifacts

- PR #286 against beta
- git-bug a620fa1 closed
- GitHub issue #283 referenced in PR
