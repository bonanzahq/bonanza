<!-- ABOUTME: Curated durable project knowledge consolidated from session journals. -->
<!-- ABOUTME: Captures stable decisions, lessons, and techniques for future work in Bonanza. -->

# Memory

## UI Patterns

- [technique] Confirmation modals use a Stimulus controller (`modal_controller.js`) with `data-controller="modal"`, `data-action="click->modal#showModal"`, and `data-modal-modalID-param="<modal-id>"`. The modal itself is a standard Bootstrap modal (`class="modal fade"`).
- [technique] Destructive actions use `button_to` with `method: :delete` inside the modal footer, paired with a cancel button using `data-bs-dismiss="modal"`.

## Authorization

- [decision] ParentItem `:destroy` is restricted to admin and leader roles. Members and hidden users have `can [:create, :read, :update, :destroy_file]` instead of `can :manage`.
- [lesson] When narrowing CanCanCan from `can :manage` to explicit actions, account for all custom actions (`:destroy_file`, `:move`, etc.) that were previously covered implicitly.
- [technique] `authorize_resource` in the controller enforces permissions server-side. View-level `can?` checks only control UI visibility — both layers are needed.

## Models

- [technique] Item soft-delete: `Item#destroy` checks `item_histories.count > 1` — if true, sets `status: :deleted`; otherwise hard-deletes. ParentItem cascades via `dependent: :destroy`.
- [technique] `ParentItem#has_lent_items?` checks `items.exists?(status: :lent)`. Use this guard before destructive operations.
- [risk] `_form.html.erb` calls `parent_item.items.first.uid.blank?` in 4 places without nil-safety. A parent item with zero items would crash the edit form. (git-bug 5599a4b tracks fixing this.)

## Testing

- [technique] Rails 8 `button_to` renders `<button type="submit">` not `<input type="submit">`. Use `assert_select "button[type=submit]", text: "..."` in controller tests.
- [lesson] Controller tests that render views require compiled assets. Run `pnpm build && pnpm build:css` in a fresh worktree before running tests.
- [technique] Build assets once per worktree, not per test run. They don't change during a test session so there's no need to watch or rebuild unless you change stylesheets/JS.
- [technique] Start a test-only PostgreSQL container with `docker start bonanza-test-db` (or create one per AGENTS.md instructions) before running the test suite locally.
- [lesson] Browser e2e tests must exercise visible UI actions; calling internal routes directly is not an acceptable substitute.
- [technique] For Turbo-driven checkout flows in this app, browser automation may need a reload or explicit form submission to reflect server-side state reliably.

## Views

- [lesson] `button_to` generates a `<form>` with a `<button>`, not an `<a>` tag. Using it inside link grids breaks styling — use `link_to` with `data-turbo-method` instead.
- [lesson] `button_to` with Turbo enabled inside modals can prevent flash messages from rendering when combined with `data-turbo-permanent`. Disable Turbo on delete actions in modals with `data: { turbo: false }`.

## Checkout / Lending Flow

- [decision] Checkout form (`checkout/_confirmation.html.erb`) uses `line_items_attributes[N]` keyed by the outer `line_item_index`, not an inner accessory index. Using an inner index caused param collisions across line items (P0 bug #290 / git-bug b35afc8).
- [technique] The sentinel empty hidden field `accessory_ids[] = ""` before accessory checkboxes is required so that unchecking all accessories for a line item still clears the HABTM association. Rails' `accessory_ids=` setter calls `reject(&:blank?)`, so the empty string is filtered and the association is replaced with an empty set.
- [decision] `finalize!` in `Lending` has dead code for `accessory_options` — the controller passes `nil`, so the `if !accessory_options.nil?` block never runs. Accessories are set during the earlier `update(params)` call via `accepts_nested_attributes_for :line_items`.

## Lending investigations

- [lesson] If a lending is invisible on the returns page, check `lendings.department_id` against the staff member's `current_department_id` before assuming broken associations or missing items.
- [technique] When investigating a reported broken lending in production, start with the concrete lending ID, borrower surname, and item UID instead of broad orphan queries.
- [technique] To validate a stranded-department hypothesis, compare active lendings in the old department, the staff member's `department_memberships`, and the `parent_items.department_id` for items in those lendings.

## Lending removal

- [decision] Removing a lending from the UI is a general department-staff action, not an orphan-specific recovery path.
- [technique] In inventory-restoring flows, use a dedicated exception for expected business-state failures and avoid rescuing broad `RuntimeError` in controllers.
- [technique] In inventory-restoring flows, lock the item row before changing quantity and use normal `save!` instead of bypassing validations.
- [decision] The lending removal UI lives on the lending show page, gated by `can?(:manage, @lending)`, and is hidden once the lending has `returned_at`.

## Database integrity

- [decision] `line_items` should have foreign keys to both `items` and `lendings`.
- [technique] Add indexes on foreign-key columns in the same migration as the foreign keys; FK checks without indexes can slow parent-table updates and deletes significantly.
- [risk] Production lendings created while bug #290 was active may have corrupted accessory assignments (wrong accessories on wrong line items). A separate data-repair audit is needed; it was explicitly deferred from PR #291.

## Agent Coordination

- [technique] Docker stack is shared across worktrees. Check `tmux show-environment | grep '^agent:@'` and send RSVP to any active PM before starting Docker containers. Stop only containers you started; don't `docker compose down` a shared stack.

## CI and tooling

- [lesson] `jdx/mise-action@v2` installs the latest `mise`, so CI can break from upstream tool-resolution changes even when repo config did not change.
- [lesson] Plain `pnpm = "10"` in `mise.toml` can resolve through a Linux binary backend that is sensitive to upstream pnpm asset naming.
- [decision] In this repo, use the npm backend for pnpm in mise: `"npm:pnpm" = "10"`.
- [technique] When CI fails during tool installation but local app code is unchanged, inspect the exact upstream release assets and backend resolution path before changing workflow logic.
