<!-- ABOUTME: Plan for extracting hardcoded German strings into Rails locale files. -->
<!-- ABOUTME: Covers views, controllers, models, mailers, JavaScript, and Devise views. -->

# I18n: Extract Hardcoded German Strings into Locale Files

## Problem

~480 hardcoded German strings are spread across ~95 files (views,
controllers, models, mailers, JavaScript). This prevents localization
and makes wording changes fragile -- every edit requires grepping the
entire codebase.

## Current State

Some i18n infrastructure already exists:

- `config/locales/de.yml` (276 lines) -- Rails standard translations
  (dates, numbers, errors) and ActiveRecord attribute labels
- `config/locales/bonanza.de.yml` (43 lines) -- Roles, statuses,
  conditions, borrower types, gendered articles, password hint
- `config/locales/devise.de.yml` (146 lines) -- Devise translations
- `config/locales/devise_invitable.de.yml` (31 lines)
- `config/locales/en.yml` (33 lines) -- Minimal placeholder

A handful of views already use `t()` for roles, gender articles,
password hints, and borrower type labels.

## Scope

| Area                  | Files | Strings | Phase |
|-----------------------|------:|--------:|:-----:|
| Controllers           |    10 |     ~42 |     1 |
| Models                |     7 |     ~30 |     1 |
| Helpers               |     1 |       1 |     1 |
| Application views     |    57 |    ~200 |     2 |
| Mailer templates      |    24 |    ~120 |     3 |
| Mailer subjects (.rb) |     3 |      12 |     3 |
| Devise views          |    12 |     ~50 |     4 |
| JavaScript            |     3 |     ~22 |     4 |
| Rake tasks            |     1 |       3 |     4 |
| **Total**             |**~95**| **~480**|       |

Note: English scaffold messages in `departments_controller.rb` and
`parent_items_controller.rb` (7 strings like "was successfully
created") also need extraction but are not counted above.

## Key Decisions

**Locale key organization: feature-based (not file-path-based)**

Keys grouped by domain, not by directory structure:

```yaml
de:
  shared:
    save: "Speichern"
    cancel: "Abbrechen"
    back: "Zurück"
    edit: "Bearbeiten"
    delete: "Löschen"
  borrowers:
    flash:
      deleted: "Die ausleihende Person wurde gelöscht."
    validation:
      insurance_required: "Haftpflichtversicherung muss überprüft werden!"
    show:
      title: "Ausleihende Person"
  lending:
    flash:
      deleted: "Ausleihe wurde erfolgreich gelöscht."
    validation:
      department_closed: "Die Werkstatt ist vorübergehend geschlossen."
```

**Locale file organization:**

- `config/locales/de.yml` -- Keep as-is (Rails framework)
- `config/locales/bonanza.de.yml` -- Keep as-is, add `shared.*` keys
- New files per domain: `borrowers.de.yml`, `lending.de.yml`,
  `checkout.de.yml`, `parent_items.de.yml`, `departments.de.yml`,
  `users.de.yml`, `mailers.de.yml`, `static_pages.de.yml`

**German only (no English translations yet)**

YAGNI. Extract to locale files for maintainability. Add English later
if localization is actually needed.

**JavaScript i18n via data attributes**

No i18n-js gem. Pass translations from server-rendered HTML using
`data-` attributes or inline `<script type="application/json">` blocks.

## Phase 1: Controllers, Models, Helpers

**~73 strings across 18 files. Estimated effort: 6 hours.**

Low risk. Flash messages and validation errors are isolated strings
with no layout impact. However, ~36 test assertions reference German
text and will need updating.

### Controllers (10 files, ~42 strings)

| File | Strings | Examples |
|------|--------:|---------|
| `borrowers_controller.rb` | 8 | Registration confirmation, deletion, GDPR purge, email send errors |
| `lending_controller.rb` | 7 | "Ausleihe wurde erfolgreich gelöscht", "Diese Ausleihe existiert nicht", duration change |
| `checkout_controller.rb` | 4 | "Fehler! Du müsst eine ausleihende Person angeben", "Nicht so schnell", completion messages |
| `returns_controller.rb` | 3 | "Artikel zurückgenommen!", return failure |
| `users_controller.rb` | 5 | "Benutzer wurde gelöscht", email change notice, department switch, invalid department |
| `users/invitations_controller.rb` | 2 | Invitation deleted/failed |
| `parent_items_controller.rb` | 3 | Invalid department, active lendings, moved notification |
| `departments_controller.rb` | 4 | Staff/unstaff success/failure (uses `#{@department}` -- see Bugs section) |
| `static_pages_controller.rb` | 6 | Legal text update notices (4 flash messages), placeholder labels ("Datenschutzbestimmungen", "Impressum") |
| `application_controller.rb` | 1 | "Du musst angemeldet sein" |

Pattern: `redirect_to path, notice: I18n.t('borrowers.flash.deleted')`

### Models (7 files, ~30 strings)

| File | Strings | Examples |
|------|--------:|---------|
| `lending.rb` | 7 | Department closed, item unavailable, wrong department, quantity, registration, must be available |
| `conduct.rb` | 7 | 5 validation messages, 1 escalation reason ("Automatische Sperre nach..."), 1 duration check |
| `borrower.rb` | 4 | Insurance check, ID check, TOS acceptance, (1 commented out) |
| `user.rb` | 2 | Can't delete self, last admin |
| `item.rb` | 2 | Restore error, lent item error |
| `line_item.rb` | 3 | Quantity exceeds borrowed, UID uniqueness, (1 commented out) |
| `parent_item.rb` | 1 | Accessories while lent (1 commented out) |

Pattern: `errors.add(:base, I18n.t('lending.validation.department_closed'))`

### Helpers (1 file, 1 string)

- `application_helper.rb`: "Gelöschter Benutzer" fallback text

### Testing

Run `bundle exec rails test` after extraction. All 200+ tests must
pass. ~36 test assertions across 14 test files reference hardcoded
German text and will need updating:

- 4 controller tests (flash message assertions)
- 7 model tests (error message assertions)
- 2 borrower mailer tests
- 5 devise mailer tests
- 6 navigation integration tests
- 5 devise locale integration tests
- Other scattered assertions

Update assertions to use `I18n.t()` calls rather than hardcoded
strings so future wording changes don't break tests.

## Phase 2: Application Views

**~200 strings across 57 files. Estimated effort: 12 hours.**

Work by domain to keep locale files coherent. Extract shared button
labels first since they appear everywhere.

### Sub-phase 2a: Shared partials and layouts (7 files)

Extract common strings that appear across all domains:

- `shared/_user_menu.html.erb` -- "Account bearbeiten", "Verwaltung",
  "Abmelden" (renders on every authenticated page)
- `shared/_footer.html.erb` -- "Öffnungszeiten & Infos der Werkstätten"
- `shared/_management_menu.html.erb` -- "Ausleihende hinzufügen",
  "Werkstatt vorübergehend schließen"
- `shared/_form_errors.html.erb` -- error heading
- `shared/_weekly_activity_grid.html.erb` -- day labels
- `layouts/application.html.erb` -- page title
  "Bonanza Redux | Das Ausleihsystem an der FH Potsdam"
- `layouts/_unstaffed_message.html.erb` -- unstaffed warning

Add shared keys to `bonanza.de.yml`:

```yaml
de:
  shared:
    save: "Speichern"
    cancel: "Abbrechen"
    back: "Zurück"
    edit: "Bearbeiten"
    delete: "Löschen"
    search_borrowers: "Ausleihende suchen"
```

### Sub-phase 2b: Borrowers (11 files)

- `_borrower.html.erb` -- Largest file, ~16 German occurrences. Conduct
  modals, status badges, action buttons.
- `_form.html.erb`, `_self_register_form.html.erb` -- Form labels
- `_borrower_item.html.erb` -- Lending/conduct display
- `_search.html.erb` -- Search placeholder, filter labels
- `index.html.erb`, `show.html.erb`, `edit.html.erb` -- Headings, links
- `self_register.html.erb` -- Registration heading
- `confirmation_success.erb`, `email_confirmation_pending.html.erb`

### Sub-phase 2c: Checkout, Lending, Returns (12 files)

- `checkout/_borrower.html.erb` -- "Wähle die ausleihende Person"
- `checkout/_confirmation.html.erb` -- "Ausleihe prüfen",
  "Abschließen & drucken", duration selector, conduct warnings
- `checkout/_result_borrower.html.erb` -- Verification status block
- `lending/show.html.erb` -- Return date, duration change form
- `lending/index.html.erb` -- Lending list
- `lending/printable_agreement.html.erb` -- Print view
- `lending/show_public.html.erb` -- Public lending view
- `lending/_sidebar_cart.html.erb` -- Cart sidebar
- `returns/index.html.erb`, `returns/_main.html.erb` -- Return flow
- `returns/_result.html.erb`, `returns/_bnz_item.html.erb`

### Sub-phase 2d: Parent Items, Departments (12 files)

- `parent_items/_form.html.erb` -- 15 German occurrences (form labels,
  tags, accessories, item type)
- `parent_items/show.html.erb`, `_bnz_parent_item.html.erb` -- Display
- `parent_items/_item_history.html.erb` -- History labels
- `departments/_form.html.erb`, `_details_card.html.erb` -- Form fields
- `departments/index.html.erb`, `management_*.html.erb` -- Management

### Sub-phase 2e: Users, Static Pages, Statistics, Errors (15 files)

- `users/_form.html.erb` -- 5 German occurrences (role assignment,
  department, password)
- `users/index.html.erb` -- User list
- `static_pages/index.html.erb` -- Landing page (long text block)
- `static_pages/lender.html.erb` -- Staff view
- `static_pages/_edit_*.html.erb` -- Legal text editing
- `statistics/index.html.erb` -- "Statistik", "Ausleihen",
  "Beliebteste Artikel"
- `errors/not_found.html.erb`, `errors/internal_server_error.html.erb`

### Testing

Run full test suite after each sub-phase. Visually spot-check pages in
development for `translation_missing` spans (Rails default for missing
keys).

## Phase 3: Email Templates and Mailer Subjects

**~132 strings across 27 files. Estimated effort: 8 hours.**

Highest complexity. HTML email templates are 200+ line files with inline
styles. Each email has `.html.erb` and `.text.erb` variants with
duplicated German text. Both variants must use the same locale keys.

### Mailer subjects (3 .rb files, 12 subjects)

Straightforward extraction:

```ruby
# Before
mail(to: @borrower.email, subject: 'Bestätige Deine Registrierung')

# After
mail(to: @borrower.email, subject: I18n.t('mailers.borrower.confirm_email.subject'))
```

Note: `lending_mailer.rb` subjects use ASCII transliteration
("Ausleihbestaetigung", "Rueckgabe", "ueberschritten") -- probably a
workaround for encoding issues that no longer apply. Fix during
extraction by using proper German characters in locale strings.

### Borrower mailer (10 templates)

| Template | Complexity | Notes |
|----------|:----------:|-------|
| `confirm_email` | Low | Simple greeting + confirmation link |
| `account_created_email` | Low | Account created notification |
| `ban_notification_email` | **High** | Complex interpolation: user name (with fallback), duration OR permanent, department with gendered article |
| `ban_lifted_notification_email` | Medium | Department with gendered article |
| `auto_ban_notification_email` | Medium | Duration + gendered department |

### Lending mailer (12 templates)

| Template | Complexity | Notes |
|----------|:----------:|-------|
| `confirmation_email` | Medium | Item list, due date |
| `overdue_notification_email` | Medium | Days overdue count |
| `upcoming_return_notification_email` | Low | Reminder with date |
| `upcoming_overdue_return_notification_email` | Low | Last reminder |
| `duration_change_notification_email` | Medium | Old and new dates |
| `department_staffed_again_notification_email` | Low | Reopen notice |

### User mailer (2 templates)

- `todays_returns_email` -- Daily digest with lending count and item
  count interpolation.

### Devise mailer (5 templates in `devise/mailer/`)

- `confirmation_instructions`, `email_changed`, `invitation_instructions`,
  `password_change`, `reset_password_instructions`
- Some of these may already have keys in `devise.de.yml` -- check
  before adding duplicates.

### Approach for HTML emails

Extract text content only. Never modify HTML structure or inline styles.
Use `I18n.t()` with `_html` suffix for strings that contain HTML:

```yaml
de:
  mailers:
    borrower:
      ban_notification:
        body_html: "Du wurdest leider heute von %{user} %{duration_text} von der Ausleihe %{department} ausgeschlossen."
```

### Testing

Use `ActionMailer::Preview` classes to verify email rendering after
extraction. Run full test suite. Send test emails to Mailpit
(localhost:8025) and visually inspect.

## Phase 4: JavaScript, Devise Views, Cleanup

**~74 strings across 16 files. Estimated effort: 6 hours.**

### JavaScript (3 files, ~22 strings)

**`form_validation_controller.js`** (~18 messages)

Complete German validation message dictionary. Approach: render
translations as a JSON block in the layout and read from JS.

```erb
<!-- In application layout -->
<script type="application/json" id="js-translations">
  <%= raw({ validation: {
    value_missing: t('js.validation.value_missing'),
    ...
  }}.to_json) %>
</script>
```

```javascript
// In controller
const translations = JSON.parse(
  document.getElementById('js-translations').textContent
)
```

**`datepicker_controller.js`** (3 strings)

Month names and "Nächster Monat". `de.yml` already has month and day
names under `de.date.*` -- reuse those via data attributes on the
datepicker element.

**`application.js`** -- 1 commented-out string, ignore.

### Devise views (12 files, ~50 strings)

- `sessions/new.html.erb` -- Login form
- `registrations/new.html.erb`, `edit.html.erb` -- Registration/profile
- `passwords/new.html.erb`, `edit.html.erb` -- Password reset
- `invitations/new.html.erb`, `edit.html.erb` -- Invitation flow
- `shared/_error_messages.html.erb`

Check `devise.de.yml` and `devise_invitable.de.yml` for existing keys
before adding new ones. Devise has its own key hierarchy
(`devise.sessions.new.sign_in`, etc.).

### Cleanup

- Fix `lending_mailer.rb` ASCII transliterations (use proper umlauts)
- Fix `departments_controller.rb` line 73: `"#{@department}"` uses
  `to_s` -- should use `@department.name` (then extract to locale key)
- `lib/tasks/bootstrap.rake` (3 placeholder strings) -- low priority
- Enable `config.i18n.raise_on_missing_translations = true` in test
  environment permanently

## Consolidation Opportunities

These patterns appear in multiple places and should use shared keys:

| Pattern | Occurrences | Shared key |
|---------|:-----------:|------------|
| "Speichern" / "Abbrechen" / "Zurück" buttons | Every form | `shared.*` |
| "Ausleihende suchen" placeholder | 3 search fields | `shared.search_borrowers` |
| "Öffnungszeiten & Infos der Werkstätten" | Footer + mailers | `shared.department_info_link` |
| Verification block (ID checked, insurance, TOS) | 3+ views | `borrowers.verification.*` |
| Mailer greeting ("Hallo %{name}") | All mailer templates | `mailers.shared.greeting` |
| Mailer sign-off | All mailer templates | `mailers.shared.sign_off` |

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Breaking email HTML rendering | Extract text only, never touch HTML structure or inline styles. Verify with ActionMailer previews. |
| Missing interpolation variables | Enable `raise_on_missing_translations` in test env. All `%{var}` must match `t()` call arguments. |
| Locale key typos | Keep keys close to domain vocabulary. Review diffs carefully. |
| JS translations not available in cached pages | Render JSON block in layout (always server-rendered), not in cached fragments. |
| Devise key conflicts | Check existing `devise.de.yml` before adding keys. Devise has its own key hierarchy. |
| Flash message test assertions break | ~36 assertions across 14 test files reference German text. Update to use `I18n.t()` in tests. Budget time for this in Phase 1. |

## Bugs Found During Audit

1. **`lending_mailer.rb` ASCII transliterations**: Subjects like
   "Ausleihbestaetigung", "Rueckgabe", "ueberschritten" use ASCII
   instead of proper German characters. Likely a workaround for
   encoding issues that no longer apply in modern Ruby/Rails. Fix
   during Phase 3.

2. **`departments_controller.rb` lines 73, 75, 87, 89**: Flash messages
   use `"#{@department}"` which calls `to_s` on the Department model.
   `Department` has no `to_s` override, so this produces
   `#<Department:0x...>` garbage in flash messages. Affects all four
   staff/unstaff flash messages. Fix during Phase 1 by using
   `@department.name` and extracting to locale keys.

3. **`bootstrap.rake` has 3 placeholder strings, not 2**: Also includes
   "Das Impressum muss noch festgelegt werden."

## Total Effort Estimate

| Phase | Scope | Hours |
|:-----:|-------|------:|
| 1 | Controllers, models, helpers + test updates | ~6 |
| 2 | Application views (5 sub-phases) | ~12 |
| 3 | Email templates, mailer subjects | ~8 |
| 4 | JavaScript, Devise views, cleanup | ~6 |
| **Total** | | **~32** |

Each phase is independently shippable. Phase 1 can be merged and
deployed before starting Phase 2.
