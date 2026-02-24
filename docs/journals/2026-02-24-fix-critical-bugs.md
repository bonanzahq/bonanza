# fix-critical-bugs session

## Task

Fix three independent bugs bundled into one PR on branch `fix/critical-bugs`.

## Bugs Fixed

### Bug 1: Verwaltung link hidden from members and leaders (git-bug 7147963)

- **Root cause:** `_user_menu.html.erb` checked `can? :manage, department` which only admins satisfy. Members and leaders have `can :update, Department`, not `:manage`.
- **Fix:** Changed to `can? :update, current_user.current_department`
- **Tests:** Updated navigation integration tests: member and leader see the link, guest does not.

### Bug 2: Searchkick::InvalidQueryError not rescued (git-bug fe91f72)

- **Root cause:** `Borrower.search_people` rescued connection errors but not `Searchkick::InvalidQueryError`. Malformed queries (special characters) caused unrescued 500s.
- **Fix:** Added `Searchkick::InvalidQueryError` to the rescue clause in `borrower.rb`.
- **Tests:** Added model test that stubs search to raise the error and verifies graceful return.
- **Side effect:** Fixed 3 of 4 pre-existing controller test failures that were 500ing without ES. The remaining 1 failure is the same pattern in `ParentItem.search` (not in scope).

### Bug 3: JS operator precedence in borrower form validation (git-bug 3a92054)

- **Root cause:** `! value == "student"` evaluates as `(!value) == "student"` due to JS operator precedence, always returning false. This made student_id always required regardless of borrower type.
- **Fix:** Added parentheses: `!(value == "student")`
- **Note:** `student_id_input_controller.js` only toggles CSS visibility, no HTML `required` attribute, so no changes needed there.

## E2E Verification

Started full Docker stack, tested all three fixes manually in browser:

1. Member login sees and can navigate to Verwaltung link
2. Malformed search query `test[invalid{query` returns gracefully, no 500
3. Employee borrower form submits without student_id; student form still requires it

All confirmed working by Fabian.

## PR

https://github.com/bonanzahq/bonanza/pull/156

## Observations

- `ParentItem.search` has the same missing rescue for `Searchkick::InvalidQueryError` (causes the 1 remaining test failure). Not in scope for this PR but worth a follow-up.
- Test suite: 452 runs, 1 failure (pre-existing ParentItem/ES issue), down from 4 failures before this work.
