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
