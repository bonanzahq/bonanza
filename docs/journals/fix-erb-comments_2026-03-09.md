# Fix ERB inside HTML comments

## Problem

GitHub issue #215: the lending index (`/ausleihe`) crashed with a
`TypeError: no implicit conversion of nil into Array` for user_id 57.

Root cause: ERB tags inside HTML comments (`<!-- <% %> -->`) still execute
in Rails. The lending index had a department selector wrapped this way.
When a non-admin user's current department was hidden,
`Department.where(hidden: false)` excluded it, `.compact!` found no nils
to remove, returned `nil`, and `Array + nil` raised the TypeError.

## What we did

### Fix (PR #220, merged to beta)

Grepped the entire codebase for `<!--.*<%` in `.html.erb` files. Found 4
instances across 4 files:

| File | Action |
|------|--------|
| `app/views/lending/index.html.erb` | Deleted dead department selector (lines 21-27) |
| `app/views/lending/_item.html.erb` | Deleted entire file (unused partial, all content commented out) |
| `app/views/users/_form.html.erb` | Deleted dead role display block (superseded by working code below it) |
| `app/views/devise/invitations/new.html.erb` | Deleted dead link |

Also removed orphaned `data-controller="depts-selector"` attribute and
`depts-selector:setDept@document->autocomplete#setSource` action listener
from the lending index form (addressed Copilot review feedback).

### Test

Added integration test `"index succeeds when user belongs to hidden
department"` — confirmed it fails before the fix (500) and passes after.

Full suite: 664 tests, 0 failures.

### E2E verification

Stood up Docker Compose stack and verified in Chrome:
- Lending index as admin and member: renders correctly
- User edit form as member (non-admin `else` branch): renders correctly
- Invitation form as admin: renders correctly
- Zero HTML comments containing ERB on any page

## Follow-up

Filed git-bug `6cda937`: remove the now-unused `depts_selector_controller.js`
Stimulus controller and its registration. Low priority, not a launch blocker.
