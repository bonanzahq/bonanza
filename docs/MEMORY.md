# Memory

Consolidated durable insights from sessions on this project.

## Test Environment Setup

- [lesson] After creating a worktree, run `pnpm install && pnpm build && pnpm build:css`
  before running integration tests. Without compiled assets in `app/assets/builds/`, any
  test that renders an HTML view will error with `The asset "application.css" is not
  present in the asset pipeline`.

- [technique] Build assets once per worktree, not per test run. They don't change during
  a test session so there's no need to watch or rebuild unless you change stylesheets/JS.

## Checkout / Lending Flow

- [decision] Checkout form (`checkout/_confirmation.html.erb`) uses
  `line_items_attributes[N]` keyed by the outer `line_item_index`, not an inner accessory
  index. Using an inner index caused param collisions across line items (P0 bug #290 /
  git-bug b35afc8).

- [technique] The sentinel empty hidden field `accessory_ids[] = ""` before accessory
  checkboxes is required so that unchecking all accessories for a line item still clears
  the HABTM association. Rails' `accessory_ids=` setter calls `reject(&:blank?)`, so the
  empty string is filtered and the association is replaced with an empty set.

- [decision] `finalize!` in `Lending` has dead code for `accessory_options` — the
  controller passes `nil`, so the `if !accessory_options.nil?` block never runs.
  Accessories are set during the earlier `update(params)` call via
  `accepts_nested_attributes_for :line_items`.

## Data Integrity

- [risk] Production lendings created while bug #290 was active may have corrupted
  accessory assignments (wrong accessories on wrong line items). A separate data-repair
  audit is needed; it was explicitly deferred from PR #291.

## Agent Coordination

- [technique] Docker stack is shared across worktrees. Check `tmux show-environment | grep
  '^agent:@'` and send RSVP to any active PM before starting Docker containers. Stop only
  containers you started; don't `docker compose down` a shared stack.
