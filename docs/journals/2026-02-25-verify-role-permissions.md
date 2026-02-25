# Role Permissions Audit

## Ability.rb Analysis

### Current Rules by Role

**Admin** (`user.admin?`):
- `can :manage, :all` -- full access to everything

**Leader** (`user.leader?`):
- `can :update, User, id: user.id` -- update self
- `can :update, User` (block) -- update non-admin users in same department
- `can :send_password_reset, User` (block) -- reset passwords for non-admin, non-self users in same department
- `can :manage, Borrower` -- full CRUD on all borrowers (not department-scoped!)
- `can :update, Department, id: current_department.id` -- update own department
- `can :unstaff, Department, id: current_department.id` -- unstaff own department
- `can :staff, Department, id: current_department.id` -- staff own department
- `can :manage, ParentItem, department_id: current_department.id` -- full CRUD items in own department
- `can :manage, Lending, department_id: current_department.id` -- full CRUD lendings in own department
- `can [:edit, :update], :checkout` -- manage checkout flow
- `can :take_back, LineItem` (block) -- take back items in own department
- `can :read, :all` -- read everything

**Member** (`user.member?`):
- `can :update, Department, id: current_department.id` -- update own department
- `can :unstaff, Department, id: current_department.id` -- unstaff
- `can :staff, Department, id: current_department.id` -- staff
- `can :update, User, id: user.id` -- update self only
- `can :read, User` -- read users
- `can :manage, Borrower` -- full CRUD on all borrowers
- `can :manage, ParentItem, department_id: current_department.id` -- full CRUD items in own department
- `can :manage, Lending, department_id: current_department.id` -- full CRUD lendings in own department
- `can [:edit, :update], :checkout` -- manage checkout flow
- `can :take_back, LineItem` (block) -- take back items in own department
- `can :read, :all` -- read everything

**Guest** (`else` branch -- note: this is NOT `elsif user.guest?`):
- `can :read, Department` -- read departments
- `can :update, User, id: user.id` -- update self
- `can :read, Borrower` -- read borrowers
- `can :read, Lending` -- read lendings
- `can :read, ParentItem` -- read parent items

**Unauthenticated** (nil user):
- `can :read, Department` -- read departments only

## Issues Found

### Bug 1: Guest branch uses `else` not `elsif`
Line in ability.rb: `else user.guest?`
This means the `user.guest?` expression is evaluated but its result is discarded.
The `else` branch runs for ANY role that isn't admin, leader, or member -- including
`hidden` and `deleted` roles. This is a security issue: hidden/deleted users get
guest-level permissions instead of being denied all access.

### Issue 2: Member can update Department
Members can `update`, `staff`, and `unstaff` their department. The AGENTS.md spec says
members should manage borrowers/items/lendings but NOT departments. Need to verify this
is intentional.

### Issue 3: Missing abilities not covered by tests
- `send_password_reset` for leader (tested nowhere)
- `:checkout` resource abilities for leader/member
- `:take_back` on LineItem
- `LegalText` editing (only admin should be able to, enforced in controller with `authorize!`)
- Leader cannot `:create` or `:destroy` users (only update) -- is this correct?
- Leader cannot `:create` Department -- correct, only admin can
- Guest cannot access checkout
- Guest cannot create/update/destroy borrowers, items, lendings
- `change_duration` on Lending -- who can do this?

### Issue 4: LegalText not in Ability model
`static_pages_controller.rb` uses `authorize! :edit, LegalText` but LegalText is never
mentioned in ability.rb. This means only admin (via `can :manage, :all`) can edit legal
texts. This seems correct but should be tested.

### Issue 5: AutocompleteController has no authorization
`autocomplete_controller.rb` only checks `authenticate_user!` but has no `authorize!`
calls. Any logged-in user (including guests) can hit the autocomplete endpoints.

### Issue 6: StatisticsController has no authorization
Only checks `authenticate_user!`, no CanCanCan checks.

### Issue 7: LendingController missing some authorization
- `index` -- no authorize! call
- `populate`, `remove_line_item`, `update`, `empty` -- no authorize! calls
- `destroy` -- no authorize! call (manual check: `@lending.user.current_department == @current_user.current_department`)
- `change_duration` -- has `authorize! :change_duration, @lending` but `change_duration` isn't defined in Ability for non-admin roles
- `show` -- skips authorization explicitly

### Plan

1. Fix Bug 1 (else -> elsif for guest, add explicit denial for hidden/deleted)
2. Add comprehensive Ability model tests for all missing cases
3. Fix permission gaps as found
4. Document member department access decision (ask Fabian if unsure)
