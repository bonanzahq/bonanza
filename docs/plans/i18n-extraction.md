# I18n: Extract hardcoded German strings into locale files

## Problem

~204 hardcoded German user-facing strings are spread across ~61 files.
This prevents future localization and creates maintenance issues when
wording needs to change.

## Scope

### HIGH priority (user-facing, should be done first)

**View templates (~40 files, ~120 strings)**
- Borrower views: "Ausweis geprüft", "Haftpflicht geprüft", "Möchtest Du
  die Sperre jetzt aufheben?", "Schließen", etc.
- Checkout views: "Wähle die ausleihende Person", "Ausleihe prüfen",
  "Abschließen & drucken"
- Lending views: "Rückgabe am", "Rückgabedatum ändern", "Änderung speichern"
- Returns views: "Rücknahme", "Überfällig", "zurückgegeben"
- Parent item views: "Schlagwörter", "Zubehör", "Artikelart ändern?"
- Department views: "Öffnungszeiten", "Geöffnet?"
- User views: "Zugewiesene Rolle", "Primäre Werkstatt", "Passwort ändern"
- Static pages: landing page text, registration prompts
- Devise views: "Passwort zurücksetzen", "Registrierung abschließen"
- Error pages: "Es ist ein unerwarteter Fehler aufgetreten..."

**Mailer templates (5 files, ~25 strings)**
- borrower_mailer: confirm_email, ban_notification, ban_lifted
- devise invitation_instructions
- Mailer subjects in borrower_mailer.rb
- Shared footer text duplicated across 4 templates

**Controller flash messages (8 files, ~18 strings)**
- borrowers_controller: registration confirmation messages
- checkout_controller: validation errors
- returns_controller: return success/failure
- lending_controller: deletion, duration change
- users_controller, departments_controller

### MEDIUM priority

**Model validations (5 files, ~16 strings)**
- lending.rb: "Die Werkstatt ist vorübergehend geschlossen..."
- borrower.rb: "Haftpflichtversicherung muss überprüft werden!"
- user.rb: "Das eigene Konto kann nicht gelöscht werden."
- item.rb, line_item.rb: various error messages

**JavaScript (2 files, ~22 strings)**
- form_validation_controller.js: complete German validation dictionary
- datepicker_controller.js: month names
- Needs JS-side i18n approach (data attributes or JS locale loading)

### LOW priority

**Rake tasks (1 file, 3 strings)**
- bootstrap.rake: initial legal text placeholders

## Approach

1. Work by domain (borrowers, lending, checkout, etc.) not by file type
2. Use Rails `t()` helper in views, `I18n.t()` in controllers/models
3. Organize locale keys by feature, not by file path
4. Extract shared patterns into partials where duplicated
5. JavaScript strings: pass via data attributes from server-rendered HTML

## Consolidation opportunities

- "Ausweis geprüft" / "Haftpflicht geprüft" / "Reg. bestätigt" block
  appears in 3+ views - extract to shared partial
- Mailer footer text duplicated across 4 templates - extract to layout
- "Zurück" link pattern repeated everywhere

## Bugs found during audit

- departments_controller.rb line 64: string interpolation in single quotes
  (Ruby bug, not just i18n)
