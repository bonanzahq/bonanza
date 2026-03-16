# Fix gendered person-referring terms

Branch: `fix-gender-text`
GitHub issue: #232
PR: #238 (against beta)

## What was done

Replaced all gendered German person-referring terms with gender-neutral
alternatives across 20 files (17 source + 3 test).

## Replacements

| Old | New | Files |
|-----|-----|-------|
| `Mitarbeiter/in` | `Angestellt` | borrower badge (2 views) |
| `Ausleiher*in editieren` | `Ausleihende Person editieren` | borrower edit heading |
| `ein Mitarbeitender der` | `jemand aus der` | email templates (3 files) |
| `Gelöschter Benutzer` | `Gelöschtes Konto` | helper + ban emails (4 locations) |
| `Benutzer` / `Benutzer-Konto` / `Benutzeraccount` | `Konto` | controllers, views, locales, emails |
| `Student*in` | `Studierende` | landing page |
| `Ehemaliger Mitarbeiter` | `Ehemalige Fachkraft` | GDPR anonymization (user.rb) |

## Not changed (intentionally)

- `Department#genderize` — grammatical gender for department name articles
  (der/die/das), not person references
- `Studierenden-/Mitarbeitendenausweis` — structural slash separating two
  types of ID card; both compound parts already gender-neutral
- `member: "Mitarbeitend"` in locales — already a gender-neutral participial
  adjective

## Grammar notes

- `keinen Benutzeraccount` (masc) became `kein Konto` (neuter) — article
  change required in all 4 occurrences
- `Ehemaliger` (masc adj) became `Ehemalige` (fem adj) to agree with
  `Fachkraft` (fem noun, but semantically gender-neutral)
- `user: Benutzer` in devise.de.yml changed to `user: Konto` — Devise uses
  this in error messages like "Konto konnte nicht gespeichert werden"

## Tests

675 runs, 1323 assertions, 0 failures. Updated 3 test files to match new
strings.
