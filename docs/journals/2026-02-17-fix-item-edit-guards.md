# Fix Item Edit Guards

Branch: `fix-item-edit-guards`
PR: https://github.com/bonanzahq/bonanza/pull/116

## Summary

Fixed two bugs about item editability when items are lent, plus several issues discovered during E2E testing.

## Bug 1: Item note field locked while lent (git-bug 459ce86)

**Problem:** `Item#item_cannot_be_changed_if_lent` blocked ALL field changes on lent items except status. Staff need to edit notes on lent equipment.

**Fix:**
- Changed validation to check `changed - %w[note status]` instead of blocking everything
- Removed `disabled` from note textarea in form for lent items
- Removed `reject_if` proc on `accepts_nested_attributes_for :items` that silently discarded all nested attributes for lent items (the model validation is the proper guard)

## Bug 2: Accessories editable while child is lent (git-bug 928969a)

**Problem:** No guard prevented accessory changes on a parent item when any child item was lent.

**Fix:**
- Added `accessories_cannot_change_if_lent` validation to ParentItem
- Render accessories as read-only plain text (not disabled form fields) when items are lent, avoiding nil attribute issues in `reject_accessory`
- Added nil-safe `strip!` in `reject_accessory` as defense in depth

## Issues discovered during E2E testing

### Disabled form fields don't submit values
When accessory fields were `disabled`, their `name` values weren't submitted. `reject_accessory` called `strip!` on nil, causing a 500. Fixed by rendering accessories as plain text instead of disabled fields when lent.

### Dual-tab form submitting conflicting data
The form has two tabs (unique items / amount items) that both render `fields_for :items`. The inactive amount tab was submitting conflicting attributes (`uid=""`, `_destroy=true`) for the lent item. Fixed by having the `inline-tabs` Stimulus controller disable all fields in the inactive tab pane.

### Hidden quantity field causing phantom changes
The hidden `quantity` field hardcoded `value=1` for unique items. Lent items have `quantity=0`, so the form always sent a phantom change. Fixed by using the item's actual quantity for lent items.

### Unlocalized error messages
The error heading was English ("X errors prohibited...") and nested errors had an "Items" prefix from `full_message`. Fixed by localizing the heading to German and switching to `error.message`.

## Files changed

- `app/models/item.rb` - validation allows note changes
- `app/models/parent_item.rb` - accessory guard validation, removed reject_if, nil-safe strip
- `app/views/parent_items/_form.html.erb` - note enabled, accessories read-only when lent, localized errors, lent quantity, data-lent-disabled markers
- `app/javascript/controllers/inline_tabs_controller.js` - disable inactive tab fields
- `test/models/item_test.rb` - updated/added lent item tests
- `test/models/parent_item_test.rb` - accessory guard tests, nested attribute test
- `test/factories/accessories.rb` - new factory

## Tests

170 model tests pass, 0 failures. Full E2E browser testing verified all scenarios.

## Open follow-up

git-bug `3c6e213` - Style validation error messages and disabled field presentation in parent item form.
