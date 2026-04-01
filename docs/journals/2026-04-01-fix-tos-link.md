# fix-tos-link session

Branch: `fix-tos-link`
PR: #277 (against beta)
git-bug: 8e11cdb (closed)
GitHub issue: #276

## What we did

Fixed TOS visibility in borrower forms (P0 issue).

### Staff borrower form (new/edit)
- Added a link to `/ausleihbedingungen` next to the TOS checkbox, opening in a new tab
- Link is a sibling of the label (not nested inside) for accessibility

### Self-registration form
- Embedded the full TOS content (from `LegalText.current_tos`) directly on the registration page in a scrollable container above the form
- Checkbox label references the visible text above
- Fallback: if TOS record is missing, falls back to a link to `/ausleihbedingungen`
- Scrollable container has `tabindex="0"`, `role="region"`, `aria-label` for keyboard accessibility

### Legal text page styling
- Added `.legal-text` class to cap heading sizes on `/ausleihbedingungen`, `/datenschutz`, `/impressum` so markdown headings don't exceed page-level headings
- Added `.tos-content` class for the compact embedded TOS with 13px base font and tighter heading scale
- All styles in `application.sass.scss`, no inline CSS

### Tests
- 3 new tests: TOS link in staff new/edit forms, TOS content visible on self-registration page
- Full suite: 688 runs, 0 failures

### Copilot review
- Addressed 5 review comments: fixed accessibility (#2), fallback link (#3), link-outside-label (#4)
- Declined XSS sanitization (#1, pre-existing concern) and missing-TOS redirect (#5, handled by fallback)
- Resolved all 5 review threads

## Issues filed
- `614ed29`: Legal text pages have duplicate headings (hardcoded h2 + markdown h1). Suggested adding an editable `title` field to LegalText.
- `381b1b0`: Logo should not be h1 on every page (semantic HTML issue)
- `972b29a`: render_markdown does not sanitize link protocols (javascript: in markdown links)

## Docker notes
- Rails container had died (CSS watcher killed, JS build error). Had to restart Docker Desktop to clear a stuck container that wouldn't stop/remove.
- `docker compose down` can fail if a container is in a bad state — `docker rm -f` may also fail. Restarting Docker daemon was the only fix.
