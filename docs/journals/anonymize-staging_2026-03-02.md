# Anonymize Staging Data

## What we did

Implemented `rake staging:anonymize` to scrub all PII from a staging database
before inviting testers. This prepares for the v1 data migration (phase D).

## Files created

- `lib/tasks/staging.rake` -- the rake task
- `test/tasks/staging_rake_test.rb` -- 11 tests

## Key decisions

- **Email format**: Used `anon-{id}@staging.local` instead of `Faker::Internet.email`
  to guarantee uniqueness without collision risk. No DB unique index on email,
  but this is simpler and deterministic.

- **student_id format**: Used `id.to_s.rjust(8, "0")` because there IS a unique
  partial DB index on `student_id`. Faker-generated values could collide.

- **Faker seeding**: `Faker::Config.random = Random.new(record.id)` per record
  makes output deterministic and idempotent across reruns.

- **ES error resilience**: Added rescue for Elasticsearch connection errors on
  `Borrower.reindex`, matching the pattern used throughout the codebase (conduct,
  lending, borrower search). Tests run without ES.

- **Helper methods at file top level**: Defined `anonymize_borrowers`,
  `anonymize_conducts`, etc. as plain methods in the rake file, outside the
  namespace block. Standard rake pattern, keeps the task body clean.

## Issues encountered

1. Factory sequence for `student_id` starts at `s00001` -- collided with an
   explicit `student_id: "s00001"` in the test. Fixed by using `s99001`.

2. `Borrower.reindex` threw `Elastic::Transport::Transport::Error` without ES
   running. Added rescue block matching existing codebase patterns.

## PR

https://github.com/bonanzahq/bonanza/pull/200 against `beta`.
