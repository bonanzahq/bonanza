# Fix Strong Parameters -- 2026-03-13

Branch: `fix-strong-params`
PR: #234
GitHub issue: #233
git-bug: 546ed85 (closed)

## What we did

Fixed 5 instances across 4 controllers where user-submitted form data
bypassed Rails Strong Parameters:

1. **CheckoutController#select_borrower** -- accessed `params[:lending][:borrower_id]`
   directly. Added `select_borrower_params` method.

2. **CheckoutController#update** -- passed raw `params[:lending][:accessories]`
   to model. Removed it (dead code -- accessories are already handled through
   `line_items_attributes` in `checkout_params`).

3. **ReturnsController#take_back** -- passed entire `params` hash to
   `LineItem#take_back`. Added `take_back_params` permitting only `:quantity`.

4. **ParentItemsController#create/update** -- accessed raw
   `params[:parent_item][:all_tags_list]` for tagging. Added `tags_param`
   method with `.require().permit()`.

5. **UsersController#user_params** -- mutated raw `params[:user]` with
   `.delete()` before permitting. Replaced with conditional permit list
   construction (no mutation).

## Key decisions

- `all_tags_list` must NOT go in `parent_item_params` -- it's a read-only
  acts_as_taggable accessor, not a writable model attribute. Causes
  `ActiveModel::UnknownAttributeError` if included. Tags are handled
  exclusively through `tags_param`.

- The `checkout_params` method still mutates raw params internally before
  calling `.require().permit()`. Left as-is since the final permit is the
  security gate and refactoring it is a separate concern.

- `params[:lending][:accessories]` in the checkout update was dead code.
  The confirmation form submits accessories via
  `lending[line_items_attributes][i][accessory_ids][]`, which is already
  permitted in `checkout_params`.

## E2E testing

Tested all 4 flows in the browser. Caught a real bug: a worker had added
`all_tags_list` to `parent_item_params`, breaking parent item create/update.
Fixed before merge.

## Tests

Added 5 new tests verifying unpermitted params are filtered. All 182 tests
pass (0 failures, 0 errors).

## Status

PR #234 open against beta, Copilot review comments addressed and resolved,
Fabian manually verified. Awaiting merge.
