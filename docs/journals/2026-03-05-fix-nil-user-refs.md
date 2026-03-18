# Fix nil user references in views

Branch: `fix-nil-user-refs`
GitHub issue: #214 (closed via PR #221)
git-bug: `fd6c63c` (closed)

## Problem

After migrating v1 data to staging, 668 lendings reference 9 user IDs that
don't exist in the users table. Views crash with `undefined method 'fullname'
for nil` when displaying these lendings.

## What we did

### Helper method

Added `user_display_name(user)` to `ApplicationHelper` — returns
`user&.fullname || "Gelöschter Benutzer"`. Two unit tests cover the nil and
non-nil cases.

### View fixes (13 call sites across 6 files)

Replaced unguarded `.user.fullname` with `user_display_name()`:

- `borrowers/_borrower_item.html.erb` (2 sites) — lending cards
- `parent_items/_item_history.html.erb` (6 sites) — item history entries
- `lending/printable_agreement.html.erb` (1 site) — printable contract
- `static_pages/_edit_tos.html.erb` (2 sites) — TOS editor
- `static_pages/_edit_imprint.html.erb` (1 site) — imprint editor
- `static_pages/_edit_privacy.html.erb` (1 site) — privacy editor

### Mailer fix

`BorrowerMailer#ban_notification_email` crashed when `conduct.user` was nil
because it unconditionally built a `reply_to` header. Fixed to conditionally
set `reply_to` only when user exists. Used inline safe navigation in the HTML
and text templates since helper availability in mailers is less predictable.

### Views NOT changed (already guarded)

- `borrowers/_borrower.html.erb:108` — inside `if conduct.user` block
- `checkout/_confirmation.html.erb:101,109` — inside `if conduct.user` blocks

### E2E verification

Started Docker stack, created orphaned data (user_id=9999 pointing to
non-existent user) on lending, item_histories, and legal_texts using raw SQL
with FK constraints temporarily disabled. Verified through browser:

- Borrower page (`/verwaltung/2`) — "Gelöschter Benutzer" in lending card
- Item history (`/artikel/1`) — "Gelöschter Benutzer" in history entries
- Legal text admin (`/verwaltung/texte`) — "Editiert von Gelöschter Benutzer"
- Printable agreement (`/ausleihe/2/token/.../agreement`) — "Verleihende Person: Gelöschter Benutzer"

All pages rendered without errors.

### Copilot review

One comment about trailing whitespace on a line we changed in `_edit_tos.html.erb`.
Fixed and resolved.

## Commits

```
6cb6af5 test(mailer): add failing test for ban_notification_email with nil user
632a9ea feat(helpers): add user_display_name for nil-safe user display
31d603e fix(mailer): handle nil user in ban notification email
275b302 fix(views): guard against nil user references
690f56a style(views): remove trailing whitespace in _edit_tos
```

## Follow-up

Filed GitHub issue #223 / git-bug `1b2ea65`: three unguarded
`membership.user.fullname` calls in DepartmentMembership views
(`departments/index`, `_staff_card`, `users/index`). Rated P2 — theoretical
risk only, no known data triggers it.

## Technical notes

- PostgreSQL FK constraints are strict in this schema. To create orphaned
  user references for testing, you must `ALTER TABLE ... DISABLE TRIGGER ALL`,
  do the update, then re-enable. Raw `DELETE` or `UPDATE` with non-existent
  FK values will fail.
- `ItemHistory` has `condition` enum with values: `flawless`, `flawed`, `broken`
  (not `good`/`bad`).
- `belongs_to :user` on Lending is NOT `optional: true`. The orphaned records
  have non-nil `user_id` values (dangling FKs), so Rails presence validation
  still passes. No model change was needed.
