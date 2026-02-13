# B1 Bug Hunting Session

## Context

Fabian tested the containerized app over Tailscale and we tracked down bugs
together using Playwright MCP for browser automation.

## Bugs Found and Filed

### Rails Host Authorization (fixed)
- Accessing via Tailscale hostname (`amini.stonecat-hexatonic.ts.net`) was
  blocked by Rails host authorization
- Initial fix `.ts.net` wildcard suffix didn't work (was already committed
  by previous agent)
- Regex approach also didn't work
- Final fix: `config.hosts.clear` in development.rb -- host authorization
  is a production concern, not development
- Committed directly since it was blocking all testing

### ActionMailer not configured (git-bug cc7f2a6, GitHub #44)
- Creating a borrower triggers `send_confirmation_pending_email` which calls
  `BorrowerMailer.confirm_email.deliver_now`
- Mailer fails silently in Docker (no mail config), rescue rolls back the
  `email_token` save
- Borrower exists but `email_token` is nil, which crashes views that build
  `send_confirm_email_path(borrower.email_token)`
- Added nil guards to `_borrower.html.erb` and `_result_item.html.erb` with
  BUG comments referencing the git-bug issue
- Real fix: wire ActionMailer to Mailpit (dev) and FHP SMTP relay (prod)

### Turbo Frame "Content missing" (git-bug 3886815, GitHub #45)
- Clicking a borrower in /verwaltung shows "Content missing" instead of
  navigating to the detail page
- Root cause: borrower links are inside `<turbo-frame id="results">`, so
  Turbo looks for a matching frame in the show response (which has none)
- Fix: add `data-turbo-frame="_top"` to the link
- Initially committed fix but reverted -- Fabian wanted bugs tracked, not fixed

### Autocomplete CORS errors (git-bug 8be4096, GitHub #46)
- Borrower search autocomplete hardcodes `http://localhost:3000` as source URL
- Fails with CORS when accessed through Caddy (port 8080) or Tailscale
- Fix: use relative URL or Rails path helper

### Verwaltung navigation (git-bug 7913dbe, GitHub #42)
- "Verwaltung" link hidden in user avatar dropdown alongside user-scoped items
- Application settings should be in main navigation, not under user profile

### Department creation UI (git-bug 82b4fc0, GitHub #41)
- No admin UI to create new departments from Verwaltung area
- Backend exists (controller + routes) but only link is on public workshops page

### Leihvertrag print experience (git-bug 3e5fa64, GitHub synced)
- Print CSS is missing/broken -- output looks awful
- Clicking "Drucken" immediately opens print dialog via hidden iframe
- No PDF download option
- No option to email agreement to borrower

### Return comment field (git-bug e9e4713, GitHub synced)
- No way to add comments about item condition when returning (e.g. "cable
  missing", "scratched lens")

## git-bug Bridge Sync Issue

Major discovery: `git bug bridge push` was silently exporting 0 issues.

**Root cause:** Two git-bug identities exist (Claude `cff9ab1` and fmzbot
`9ce646f`). The bridge was configured with the Claude identity tagged as
`github-login: fmzbot`. The exporter only syncs issues authored by identities
with this metadata. Issues authored by the fmzbot identity were silently
skipped. The metadata is immutable and can't be transferred via CLI.

**Fix:** Set all agents to use the Claude identity:
```
git config git-bug.identity cff9ab1d2ee9741039b2a60d90cca378a5320ba753398f6f3df8d03abcebee1b
```

Also discovered `bridge pull` must be run before `bridge push` or push
silently exports 0 -- added this to AGENTS.md workflow docs.

Manually pushed 5 issues to GitHub via `gh issue create` as backfill.

## Commits

- `a1f3fb2` fix: disable host authorization in development
- `9ea4856` fix: guard against nil email_token in borrower views
- `4f95036` revert: borrower Turbo Frame fix (tracking only, not fixing)
- `c6a645c` docs: note bridge pull requirement before bridge push
- `cf23e25` docs: add git-bug identity setup for bridge sync
- `bbfc970` docs(b1): journal for bug hunting session

## Containerization Remaining Work

Per `docs/plans/b1_containerization.md`, still open:
- Phase 4: docker-compose.override.yml, helper scripts, dev workflow docs
- Phase 5: resource limits, ES security, Caddy HTTPS, backup/restore
- Phase 6: README update, troubleshooting docs

## For Next Session

**Bugs to fix (priority order):**
1. Configure ActionMailer for Mailpit (cc7f2a6 / #44) -- most impactful,
   blocks borrower creation flow
2. Fix autocomplete CORS (8be4096 / #46) -- hardcoded localhost:3000
3. Fix Turbo Frame borrower links (3886815 / #45) -- "Content missing"

**Features/enhancements:**
- Relocate Verwaltung navigation (7913dbe / #42)
- Add department creation UI (82b4fc0 / #41)
- Improve Leihvertrag: print CSS, PDF download, email (3e5fa64)
- Add return comment field (e9e4713)

**Housekeeping:**
- Clean up 8 duplicate git-bug issues from bridge pull re-importing
- Update `/git-bug` skill with identity verification and bridge sync docs
