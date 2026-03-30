# Remove public JSON files

## Task

Remove `public/items.json` and `public/items2.json` — static files containing
real equipment inventory data from an early autocomplete implementation.

## Findings

- `public/items.json` (14 KB): ~570 equipment names in a JSON array
- `public/items2.json` (58 B): 2 item names in a JSON array
- Both added in the initial commit (`fa24937`), present on main and beta
- Only code reference: a commented-out line in `autocomplete_controller.js`
  pointing to `/autocomplete/items.json` (different path, dead code)
- `parent_items_controller.rb` mentions of `.json` are standard Rails route
  comments, unrelated

## Changes

- Deleted both files via `git rm`
- Removed the commented-out source URL in `autocomplete_controller.js`
- Wrote `docs/plans/remove-public-json.md` documenting the history rewrite
  option (not executed — equipment names, not secrets)

## Outcome

PR #271 merged to beta. Files removed from HEAD. History rewrite deferred
pending Fabian's decision.

## Insights

[process] For data removal requests, always check whether the concern is
"stop serving it" (simple delete) vs "make it unrecoverable" (history rewrite).
Document both options with tradeoffs and let the stakeholder decide.
