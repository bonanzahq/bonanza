# Fix Borrower Selection

Branch: `fix/borrower-selection`
PR: #132

## Problem

Checkout borrower selection step showed no borrowers until user typed a search
query. The Verwaltung view showed them immediately.

## Root Cause

Two issues working together:
1. `checkout_controller.rb` set `@borrowers = []` when no search query present
2. View only rendered borrower list when `params[:b].present?`

## Changes

- Controller calls `search_people` for all borrower-state requests (blank query
  becomes wildcard `*` inside `search_people`)
- Removed dead `begin/rescue Faraday::ConnectionFailed` in controller —
  `search_people` already handles ES failures internally
- View always renders the results div; empty-state message shown only when a
  search query returns no results
- Bumped `per_page` from 4 to 10 in `search_people`
- Added 9 pop culture borrowers to seed data for better dev experience

## E2E Verified

- Initial load shows borrowers immediately
- Search with match returns correct results
- Search with no match shows "Keine ausleihenden Personen gefunden!"
- Verwaltung and checkout now behave consistently

## Pre-existing Issue Found

`Searchkick::InvalidQueryError` is not rescued in `search_people`. When ES has
a stale index (fullname as text field), it causes 500 errors. The rescue block
only catches connection errors, not query errors. Filed as git-bug `fe91f72`.

## Follow-up Issues Filed

- `09fd26e` (enhancement): Sort borrowers by lending frequency + pagination
- `fe91f72` (bug): Rescue `Searchkick::InvalidQueryError` in `search_people`
