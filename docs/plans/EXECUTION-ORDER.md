# Bonanza Redux: Migration Execution Order

Plan files are prefixed by phase (a/b/c/d) and step number, matching this
execution sequence.

## Context

- Bonanza v1 is running with low usage on the production server
- Redux will deploy to the **same host** as v1 (parallel migration on different ports)
- Aggressive upgrade path: Ruby 3.4+ and Rails 8.0 directly
- FHP provides SMTP relay for email
- v1 role=2 maps to "leader" in Redux; admin flag granted manually post-migration

## Dependency Graph

```
Phase A: Foundation
  a1 Yarn to pnpm ─────────────────────────────────┐
  a3 Testing Infrastructure ───────────────────────┤
  b1 Containerization (get the app running) ───────┤
  a2 Dependency Updates (Ruby 3.4 + Rails 8) ──────┘
                                                     │
Phase B: Infrastructure                              ▼
  b2 Error Handling & Observability ────────────────┐
  b3 Devise + Turbo Review ─────────────────────────┤
  b4 CI/CD & Deployment ───────────────────────────┘
                                                     │
Phase C: Features                                    ▼
  c1+c2 Background Jobs + Email (combined) ─────────┐
  c3 Conduct System ────────────────────────────────┤
  c4 GDPR & Data Retention ────────────────────────┘
                                                     │
Phase D: Cutover                                     ▼
  d1 Data Migration (v1 → Redux)
  d2 VPN coordination with FHP IT
```

## Phase A: Foundation

**Goal:** Get the codebase onto supported, secure versions with a test framework
in place and the application actually running before any feature work begins.

### A1. Yarn to pnpm Migration

- **Plan:** `a1_yarn-to-pnpm.md`
- **Effort:** Half a day
- **Why first:** Small, self-contained. Unblocks correct build tooling for
  everything that follows.

### A2. Testing Infrastructure

- **Plan:** `a3_testing.md`
- **Effort:** 1 week (foundation + core model tests)
- **Why before upgrades:** Tests must exist before the dependency upgrade so
  they can verify it doesn't break things. TDD is mandated for all new
  features.
- **Scope for this phase:** Framework setup, factories, model tests for the 6
  core models. Controller and system tests can grow incrementally during
  Phase C.

### A3. Containerization

- **Plan:** `b1_containerization.md`
- **Effort:** 2-3 weeks
- **Why before dependency updates:** We need the app actually running before
  making any further changes. Tests alone are not sufficient -- they run
  with Elasticsearch disabled and never boot the full application stack.
  Containerizing first gives us a working baseline we can verify visually
  and functionally, then the dependency upgrade can be validated against a
  running application, not just a test suite.
- **Scope:** Dockerfile, docker-compose with web + db + elasticsearch +
  caddy. Targets current Ruby 3.1.2 / Rails 7.0. Worker and scheduler
  containers are deferred to Phase C.
- **Note:** Since Redux deploys to the same host as v1, use non-conflicting
  ports during development/testing.

### A4. Dependency Updates

- **Plan:** `a2_dependency-updates.md`
- **Effort:** 2-3 weeks
- **Path:** Aggressive (Ruby 3.4+ / Rails 8.x)
- **Why after containerization:** Ruby 3.1 is EOL (Jan 2026). This is the
  most critical security issue in the project, but now we can verify the
  upgrade by running the full test suite AND booting the containerized
  application to confirm it works end-to-end.
- **Targets:** Ruby 3.4.x (or 3.5.x if stable), Rails 8.0.4+ or 8.1.x

## Phase B: Infrastructure

**Goal:** Add observability and set up deployment pipeline.

### B1. Error Handling & Observability

- **Plan:** `b2_error-handling.md`
- **Effort:** 2-3 days
- **Why now:** Get structured logging and Sentry in place before adding features.
  Debugging production issues without observability is painful.

### B2. Devise + Turbo Review

- **Plan:** `b3_devise-turbo.md`
- **Effort:** 1-2 days
- **Why now:** Authentication must work correctly before deploying to users.
  Pragmatic approach: disable Turbo on Devise forms (Option A).

### B3. CI/CD & Deployment

- **Plan:** `b4_ci-cd-deployment.md`
- **Effort:** 2-3 weeks
- **Requires:** Containerization complete, tests running
- **Note:** Since same host as v1, the deployment script needs to handle port
  conflicts. Beta can run on a different port on the same machine.

## Phase C: Features

**Goal:** Implement the feature gaps between v1 and Redux.

### C1+C2. Background Jobs + Email Notifications (Combined)

- **Plans:** `c1_background-jobs.md` + `c2_email-notifications.md`
- **Effort:** 2-3 weeks combined
- **Why combined:** c2 depends entirely on c1. Implementing email without
  background jobs means synchronous `.deliver_now` which blocks requests.
  Build them together.
- **Execution order within:**
  1. Install Solid Queue, configure ActiveJob
  2. Add worker container to docker-compose
  3. Implement mailers with `.deliver_later` from the start
  4. Add clockwork scheduler container
  5. Implement scheduled notification tasks
- **SMTP:** FHP provides relay. Configure in environment variables.

### C3. Conduct System

- **Plan:** `c3_conduct-system.md`
- **Effort:** 1-2 days
- **Requires:** Background jobs (for `.deliver_later` in ban notifications)
- **Key work:** Replace commented-out `remove_old_automatic_conducts` with
  working PostgreSQL queries, add warning escalation logic.

### C4. GDPR & Data Retention

- **Plan:** `c4_gdpr-data-retention.md`
- **Effort:** 1-2 days
- **Requires:** Conduct system (for conduct cleanup logic)
- **Note:** Consult legal counsel on retention periods before deploying.

## Phase D: Cutover

**Goal:** Migrate production data from v1 and go live.

### D1. Data Migration

- **Plan:** `d1_data-migration.md`
- **Effort:** 2-3 weeks (including prep, test runs, and cutover weekend)
- **Key decisions already made:**
  - v1 role=2 → Redux "leader" (admins designated manually)
  - Same host: parallel migration on different ports
  - FHP SMTP for email
- **Still to verify on v1 server:**
  - Whether Paperclip file uploads exist (check early in prep)
  - v1 Elasticsearch version
- **Still to decide:**
  - Cutover weekend date
  - Who is on-call during migration
  - Whether to beta-test with real users first

### D2. VPN Coordination

- **Plan:** `d2_vpn-access.md`
- **Action:** Coordinate with FHP IT to ensure the application is only
  accessible via VPN.
- **Timing:** Can happen in parallel with D1 preparation.
