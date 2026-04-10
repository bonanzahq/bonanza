# Memory

## Testing

- [technique] Rails 8 `button_to` renders `<button type="submit">` not `<input type="submit">`. Use `assert_select "button[type=submit]", text: "..."` in controller tests.
- [lesson] Controller tests that render views require compiled assets. Run `pnpm build && pnpm build:css` in a fresh worktree before running tests.
- [technique] Start a test-only PostgreSQL container with `docker start bonanza-test-db` (or create one per AGENTS.md instructions) before running the test suite locally.

## Views

- [lesson] `button_to` generates a `<form>` with a `<button>`, not an `<a>` tag. Using it inside link grids breaks styling — use `link_to` with `data-turbo-method` instead.
- [lesson] `button_to` with Turbo enabled inside modals can prevent flash messages from rendering when combined with `data-turbo-permanent`. Disable Turbo on delete actions in modals with `data: { turbo: false }`.
