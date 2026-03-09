# Fix Rails warnings

Branch: `fix-warnings`
PR: #228
Issues: #226 (git-bug 21e9502), #227 (git-bug 0cb81a1)

## What we did

Fixed two warnings that appeared in Rails logs on staging.

### 1. Duplicated hash key in includes()

`BorrowersController#show` had `.includes(line_items: :item_histories, line_items: :accessories)`.
Ruby silently overwrites the first `line_items:` key, so `:item_histories` was never eager-loaded.

Fix: `.includes(line_items: [:item_histories, :accessories])`.

Also simplified `where.not(:lendings => { lent_at: nil})` to `where.not(lent_at: nil)` since the
query is already scoped to `@borrower.lendings` — the table qualifier was redundant. This was
flagged by Copilot's PR review.

### 2. ActiveStorage variant processor warning

`ParentItem` uses `has_many_attached :files` but no image variants are generated. The
`image_processing` gem is commented out in the Gemfile, causing Rails to log a warning on
every request.

Fix: added `config.active_storage.variant_processor = :disabled` to development.rb, test.rb,
and production.rb.

## Verification

- 667 unit/integration tests pass
- E2e tested twice: logged in, viewed borrower show pages with lending history, viewed article
  detail pages. No warnings in Rails logs.

## Commits

- `f83bb4c` fix(borrowers): merge duplicated includes hash keys
- `9b5c1e2` fix(config): disable active storage variant processor
- `643c56a` refactor(borrowers): simplify redundant table-qualified where clause
- `c3a89c3` docs(config): explain why variant processor is disabled
