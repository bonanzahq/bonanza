# Add Item Delete UI

Branch: `add-item-delete-ui`
PR: #287 (against beta)
git-bug: 63b47ae (closed), GitHub: #284

## What was done

Added a delete button to the parent item detail page with a Bootstrap
confirmation modal. The button is only visible to admin and leader roles.

### Changes

1. **Authorization (ability.rb)**: Changed member/hidden permissions from
   `can :manage, ParentItem` to `can [:create, :read, :update, :destroy_file], ParentItem`.
   This restricts `:destroy` to admin and leader only (who have `can :manage`).

2. **Controller (parent_items_controller.rb)**: Added `has_lent_items?` guard
   to the destroy action. Returns a German alert flash when items are actively
   lent, preventing deletion.

3. **View (_bnz_parent_item.html.erb)**: Added "Löschen" button (red outline)
   next to "Bearbeiten", gated by `can? :destroy`. Clicking opens a Bootstrap
   modal with the item name, a warning about cascading deletion, and
   Cancel/Delete buttons. Follows the borrower delete modal pattern
   (data-controller="modal", data-action="click->modal#showModal").

4. **Tests**: 8 new controller tests (admin/leader can destroy, member/guest
   cannot, lent items block deletion, button visibility by role) + updated 2
   ability tests to reflect restricted member/hidden permissions. All 696 tests
   pass.

### E2E verification

- Admin: sees both Bearbeiten and Löschen buttons
- Delete modal: shows item name, warning, Cancel/Delete
- Cancel: modal closes, no action
- Delete: item removed, redirect to /verwaltung
- Member: only sees Bearbeiten, no Löschen

## Observations

- [technique] The borrower delete modal pattern (`data-controller="modal"`,
  `data-action="click->modal#showModal"`, `data-modal-modalID-param`) is the
  standard way to add confirmation modals in Bonanza. Bootstrap modal JS is
  wrapped in a Stimulus controller at `app/javascript/controllers/modal_controller.js`.

- [decision] Restricted `:destroy` to admin/leader by narrowing member/hidden
  from `can :manage` to explicit action list. This is more secure than just
  hiding the button — the controller also rejects unauthorized requests via
  `authorize_resource`.

- [lesson] When changing CanCanCan from `can :manage` to explicit actions,
  you must include custom actions like `:destroy_file` and `:move` that were
  previously covered by `:manage`. The `:move` line was already separate, but
  `:destroy_file` needed to be added to the explicit list.

- [decision] ParentItem destroy cascades via `dependent: :destroy` on items.
  Each Item's custom `destroy` method handles soft vs hard delete based on
  history count. The controller guard (`has_lent_items?`) prevents deletion
  when any item is actively lent.

## Follow-up issue

Filed git-bug `5599a4b`: "Allow removing all sub-items from a parent item".
The edit form hides the "entfernen" button on Artikel #1 (index 0) via
`display:none`, preventing users from removing the first sub-item. Four
places in the form call `parent_item.items.first.uid.blank?` which would
raise NoMethodError if items is empty. Fix is straightforward (nil-safe
navigation + tab fallback).
