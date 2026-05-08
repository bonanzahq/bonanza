<!-- ABOUTME: Curated durable project knowledge consolidated from session journals. -->
<!-- ABOUTME: Captures stable decisions, lessons, and techniques for future work in Bonanza. -->

# Memory

## Lending investigations
- [lesson] If a lending is invisible on the returns page, check `lendings.department_id` against the staff member's `current_department_id` before assuming broken associations or missing items.
- [technique] When investigating a reported broken lending in production, start with the concrete lending ID, borrower surname, and item UID instead of broad orphan queries.
- [technique] To validate a stranded-department hypothesis, compare active lendings in the old department, the staff member's `department_memberships`, and the `parent_items.department_id` for items in those lendings.

## Lending force-close
- [decision] Force-close is a general department-staff action, not an orphan-specific recovery path.
- [technique] In inventory-restoring flows, use a dedicated exception for expected business-state failures and avoid rescuing broad `RuntimeError` in controllers.
- [technique] In inventory-restoring flows, lock the item row before changing quantity and use normal `save!` instead of bypassing validations.
- [decision] The force-close UI lives on the lending show page, gated by `can?(:manage, @lending)`, and is hidden once the lending has `returned_at`.

## Database integrity
- [decision] `line_items` should have foreign keys to both `items` and `lendings`.
- [technique] Add indexes on foreign-key columns in the same migration as the foreign keys; FK checks without indexes can slow parent-table updates and deletes significantly.

## CI and tooling
- [lesson] `jdx/mise-action@v2` installs the latest `mise`, so CI can break from upstream tool-resolution changes even when repo config did not change.
- [lesson] Plain `pnpm = "10"` in `mise.toml` can resolve through a Linux binary backend that is sensitive to upstream pnpm asset naming.
- [decision] In this repo, use the npm backend for pnpm in mise: `"npm:pnpm" = "10"`.
- [technique] When CI fails during tool installation but local app code is unchanged, inspect the exact upstream release assets and backend resolution path before changing workflow logic.

## E2E testing
- [lesson] Browser e2e tests must exercise visible UI actions; calling internal routes directly is not an acceptable substitute.
- [technique] For Turbo-driven checkout flows in this app, browser automation may need a reload or explicit form submission to reflect server-side state reliably.
