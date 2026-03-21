# fix-autocomplete-back

## Summary

Investigated the autocomplete back-button bug (#211/#216) and traced it to a
500 error on `/artikel/29` caused by orphaned `line_item_id` references in
`item_histories`.

## Investigation

1. Tried to reproduce the autocomplete bug locally using agent-browser.
   Could not reproduce — autocomplete teardown from PR #231 works correctly
   under normal Turbo cache lifecycle.

2. Fabian reported the bug only occurs in the department containing article 29,
   which also 500s. This was the key insight.

3. Inspected production database via `docker exec` into `bonanza-db-1`:
   - `ParentItem.find(29)` ("Nexus 9X Test", department 4) — data looks fine
   - Items 32 and 33 belong to it — data looks fine
   - All line_items and lendings have valid references
   - BUT: item_histories 41 and 755 reference line_item_ids 83 and 341,
     which don't exist in the `line_items` table

4. Production error log confirmed:
   ```
   ActionView::Template::Error: undefined method 'lending' for nil
   _item_history.html.erb:9
   ```

5. The `_item_history.html.erb` template accesses `item_history.line_item.lending`
   — when `line_item` returns nil (orphaned FK), `.lending` on nil crashes.

## Root Cause

`LineItem` had `has_many :item_histories` without a `dependent` option.
When a lending was destroyed, `has_many :line_items, dependent: :destroy`
cascade-deleted the line_items, but their item_history references were left
dangling. 34 orphaned references existed across production.

The autocomplete bug was a symptom: user clicks item link -> 500 error ->
Turbo mishandles the error response -> back button restores cached page in
a broken state.

## Fix

- Added `dependent: :nullify` to `LineItem#item_histories` (PR #257)
- Fabian cleaned up 34 orphaned references in production via SQL:
  ```sql
  UPDATE item_histories SET line_item_id = NULL
  WHERE line_item_id IS NOT NULL
  AND line_item_id NOT IN (SELECT id FROM line_items);
  ```
- The nil guard from #252 (already in beta) prevents the view crash
- PR #231's autocomplete turbo:before-cache cleanup is correct as-is

## Technical Notes

- `autoComplete.js` `unInit()` removes the wrapper div (which contains
  the results list) and event listeners — it's thorough
- The `create("div", { around: input })` in autoComplete.js checks the
  `autofocus` attribute and calls `focus()`, which triggers `start()` —
  this is the mechanism that would show stale results if the input had a
  cached value, but it's a non-issue when the 500 is fixed
- agent-browser couldn't click Turbo-enabled links properly (clicks didn't
  navigate). JavaScript `Turbo.visit()` also didn't work. Had to use
  `window.location.href` for navigation. This made browser-level
  reproduction of Turbo cache bugs difficult.

## Closed Issues

- git-bug `5850389` (autocomplete back-button bug)
- GitHub #211 (referenced in PR #257)
