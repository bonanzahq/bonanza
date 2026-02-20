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
  b1b Production Compose Split ───────────────────┤
  b1c Production Deployment ──────────────────────┤
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
- **Why first:** Small, self-contained. Unblocks correct build tooling for
  everything that follows.

### A2. Testing Infrastructure

- **Plan:** `a3_testing.md`
- **Why before upgrades:** Tests must exist before the dependency upgrade so
  they can verify it doesn't break things. TDD is mandated for all new
  features.
- **Scope for this phase:** Framework setup, factories, model tests for the 6
  core models. Controller and system tests can grow incrementally during
  Phase C.

### A3. Containerization

- **Plan:** `b1_containerization.md`
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

### A3b. Production Compose Split

- **Plan:** `b1b_production-compose.md`
- **Why now:** The development containerization is complete but everything
  is in a single docker-compose.yml with dev settings. Split into a
  production base + development override before the dependency upgrade so
  both environments can be tested.
- **Scope:** Restructure docker-compose.yml, add docker-compose.override.yml,
  update Caddyfile and entrypoint for environment awareness.

### A3c. Production Deployment

- **Plan:** `b1c_production-deployment.md`
- **Why now:** With the production compose split done, document the actual
  server setup steps. This is manual first-time deployment -- CI/CD (b4)
  automates it later.
- **Scope:** Install Docker, clone repo, create .env, build, start, verify.
- **Open decisions:** SMTP relay details, server access. Needs Fabian +
  FHP IT input. TLS handled automatically by Caddy (Let's Encrypt).

### A4. Dependency Updates

- **Plan:** `a2_dependency-updates.md`
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
- **Why now:** Get structured logging and Sentry in place before adding features.
  Debugging production issues without observability is painful.

### B2. Devise + Turbo Review

- **Plan:** `b3_devise-turbo.md`
- **Why now:** Authentication must work correctly before deploying to users.
  Pragmatic approach: disable Turbo on Devise forms (Option A).

### B3. CI/CD & Deployment

- **Plan:** `b4_ci-cd-deployment.md`
- **Requires:** Containerization complete, tests running
- **Note:** Since same host as v1, the deployment script needs to handle port
  conflicts. Beta can run on a different port on the same machine.

### B6. TLS/HTTPS for Production

- **Plan:** `tls-debugging.md`
- **Blocked:** University firewall likely blocking inbound ports 80/443,
  preventing Let's Encrypt ACME challenges. Requires FHP IT coordination.
- **Alternatives if ports stay closed:** DNS-01 challenge, institutional
  certificate, or edge reverse proxy.

## Phase C: Features

**Goal:** Implement the feature gaps between v1 and Redux.

### C1+C2. Background Jobs + Email Notifications -- DONE

Merged via PRs #118-#124, #129. Solid Queue, all mailers, scheduled jobs.

### C3. Conduct System -- DONE

Merged via PRs #122, #125, #129. Expiration logic, email wiring, escalation.

### C4. GDPR & Data Retention -- DONE

Merged via PRs #126-#128, #129, #130. Anonymization, data export, deletion
requests, audit logging.

### C5. Phase C Bug Fixes

Fix bugs discovered during Phase C integration testing. Must be resolved
before moving to Phase D.

- `b1765d9` Borrower selection view shows no initial list -- IN PROGRESS
- `c293b30` Staff-created borrowers receive no notification email -- IN PROGRESS
- `42cacfc` Retain conduct records when bans are lifted (needs schema change)
- `0eb2044` Borrower detail page UI improvements

### C6. Open Issue Review

Review all open git-bug issues not tied to a phase. Decide for each:
triage into Phase C6 (fix now) or defer to Phase D/backlog.

Issues to review:
- `fa87417` Verify role permissions for admin/leader/member
- `115bb36` Add read-more/read-less to department descriptions
- `8dac3fc` Add archived items view to verwaltung
- `01fda2b` Allow deleting users
- `1e789f4` Add PurgeCSS to asset compilation
- `7913dbe` Relocate Verwaltung link from user dropdown to main navigation
- `8be4096` Autocomplete CORS errors when accessing via Caddy proxy
- `82b4fc0` Add department creation to admin Verwaltung UI
- `3e5fa64` Improve Leihvertrag: print CSS, PDF download, email to borrower
- `e9e4713` Add comment field when returning items
- `ee1b1a0` Staff-created borrowers don't receive confirmation email
- `f7f2187` Autocomplete broken when accessing app from network (non-localhost)
- `c960606` Returns view needs search functionality
- `36a3852` Investigate file storage persistence and backup strategy
- `58fe488` Update shared Renovate config with Bundler rules
- `a09b6ba` Move Docker infrastructure files into docker/ subdirectory
- `5916e37` Email change needs proper verification flow
- `08c505b` Style Devise mailer templates to match invitation email
- `8a60474` Checkout borrower step has no explicit 'next step' button
- `7248057` Redesign left-side navigation: consolidate scattered nav links
- `0f3e59c` Department management not linked in navigation
- `352ac20` Allow assigning users to department during department creation
- `b0590e7` Upgrade staging server from Ubuntu 22.04 to 24.04
- `5af0461` Remove Node.js from production Docker image
- `4f8af1b` Switch Docker base image to ruby-slim
- `682a427` TLS/HTTPS: Debug and fix Let's Encrypt certificate provisioning
- `0cb7ace` Department switching: no UI for users in multiple departments
- `8e69ffb` Item-department binding: unclear how items are assigned to departments
- `03079a7` Discussion: role permissions for item management (Mitarbeitende)
- `7147963` Verwaltung link hidden from members due to wrong permission check
- `3153ad6` Warn users with weak passwords on login (nagware)
- `54ba6a7` Extract all hardcoded German strings into locale files
- `da8262d` Replace auto-dismissing toasts with persistent in-context error messages

## Phase D: Cutover

**Goal:** Migrate production data from v1 and go live.

### D1. Data Migration

- **Plan:** `d1_data-migration.md`
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
