# Role Permissions Audit - Session Journal

## What We Did

### 1. Audited ability.rb
Read all models, controllers, and existing tests to map every permission rule
and identify gaps.

### 2. Security fix: `else` -> `elsif user.guest?`
The guest branch in ability.rb used a bare `else`, meaning hidden and deleted
role users got guest-level permissions (read borrowers, lendings, items; update
self). Changed to `elsif user.guest?` so only actual guests get guest
permissions. Hidden/deleted users now fall through correctly.

### 3. Comprehensive test suite
Used a planner > worker > reviewer > planner > worker > reviewer subagent chain
to expand ability_test.rb from 20 tests / 41 assertions to 57 tests / 113
assertions. Covers all 7 user states (admin, leader, member, guest, hidden,
deleted, unauthenticated) across all resources (User, Department, Borrower,
ParentItem, Lending, LineItem, LegalText, :checkout).

### 4. Hidden users get member permissions
After the elsif fix, hidden users had zero permissions. Fabian and I discussed
what `hidden` actually means in the codebase -- it's staff who don't appear in
user listings for non-admins. They're "workable" per the DepartmentMembership
scope. Gave them member-level permissions via `elsif user.member? || user.hidden?`
and added `User#hidden?` method.

### 5. Added hidden user to seeds
`hidden@example.com` / `platypus-umbrella-cactus` for manual testing.

### 6. E2E browser verification
Tested all roles (admin, leader, member, guest, hidden) via browser automation.
Confirmed:
- Hidden user can now browse items, view borrowers, use the system like a member
- Guest is read-only, blocked from creating/editing
- Member can manage borrowers/items but not legal texts or invitations
- Leader has full department access minus admin-only features

### 7. Filed follow-up issues
- git-bug `13041d6`: Members can `:update` their department (should be restricted
  to `:staff`/`:unstaff` only)
- PR notes: controllers lacking authorize! calls (Autocomplete, Statistics,
  parts of Lending)

## PR
https://github.com/bonanzahq/bonanza/pull/165

## Pre-existing issue
`lending_controller_test.rb:23` fails on main too -- not our regression.

## Open follow-ups
- git-bug `13041d6`: restrict member department update to staff/unstaff only
- Controller-level authorization gaps (no git-bug yet, noted in PR)
