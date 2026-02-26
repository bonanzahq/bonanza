# fix-seeds-test

## Summary

Cleaned up duplicate hidden user creation in `db/seeds.rb`.

## Problem

The hidden user (`hidden@example.com`) was created twice:
1. A standalone `User.create!` block (added for manual testing)
2. An entry in the `role_user_data` array (added when all roles were seeded)

This caused a unique constraint violation on email. The standalone block also
missed `confirmed_at: Time.current`, making it inconsistent with other role users.

## Fix

Removed the standalone block and kept the hidden user in the `role_user_data`
array alongside leader, member, and guest. All non-admin role users are now
created through the same loop with consistent attributes.

The admin user remains standalone because it has `admin: true` and is assigned
to `User.current_user` for use in subsequent seed records.

## Notes

- Branch was rebased onto main before PR to avoid carrying stale diffs from
  the email-change-verification merge that landed while this branch was open.
