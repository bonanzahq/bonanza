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
- [technique] Start a test-only PostgreSQL container with `docker start bonanza-test-db` (or create one per AGENTS.md instructions) before running the test suite locally.

## Views

- [lesson] `button_to` generates a `<form>` with a `<button>`, not an `<a>` tag. Using it inside link grids breaks styling — use `link_to` with `data-turbo-method` instead.
- [lesson] `button_to` with Turbo enabled inside modals can prevent flash messages from rendering when combined with `data-turbo-permanent`. Disable Turbo on delete actions in modals with `data: { turbo: false }`.

