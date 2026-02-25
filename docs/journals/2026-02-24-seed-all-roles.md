# Seed All Roles

## Task

Added seed users for every department membership role so all permissions can be tested during development (git-bug `2d5a914`).

## What was done

Seed users added to `db/seeds.rb` and tested in `test/tasks/seeds_test.rb`:

| Email | Role | Admin |
|---|---|---|
| `admin@example.com` | leader | true | (existing, unchanged) |
| `leader@example.com` | leader | false |
| `member@example.com` | member | false |
| `guest@example.com` | guest | false |
| `hidden@example.com` | hidden | false |

### Implementation details

- Seeds use a data-driven `role_user_data` array with `.each` loop, matching the existing `borrower_data` pattern in the file.
- `hidden` role was added after discussion -- it has identical permissions to `guest` (falls through to the `else` branch in `ability.rb`) but differs in visibility: hidden users don't appear in user listings for non-admins.

### Process

- Used chained subagents (planner > worker > reviewer > planner > worker) for both rounds of work.
- TDD throughout: test updated first, confirmed failing, then implementation, confirmed passing.
- Reviewer caught that three repetitive `User.create!` blocks should be refactored into the data-driven pattern -- this was done in the first round.

## Commits

- `e3a260c` test(seeds): expect seed users for all department roles
- `1b6c5de` feat(seeds): add leader, member, and guest seed users
- `efb2568` refactor(seeds): replace repetitive User.create! blocks with data-driven loop
- `4a304c1` test(seeds): add assertion for hidden role user
- `7739ac8` feat(seeds): add hidden role seed user
