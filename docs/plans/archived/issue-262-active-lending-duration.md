<!-- ABOUTME: Archives the completed plan for fixing active lending extension validation bug #262. -->
<!-- ABOUTME: Records scope, implementation decisions, and verification performed in this worktree. -->

# Issue #262: Aktive Ausleihe +7 Tage schlägt fehl

## Context

Produktionsfeedback:
- Verlängerung einer aktiven Ausleihe um 7 Tage schlug mit
  "Zeitpunkt muss in der Zukunft liegen" fehl.
- Verlängerung um 14 Tage funktionierte.

GitHub: #262  
git-bug: `9d4735e`

## Plan (fulfilled)

1. Reproduktion und Ursachenanalyse in `change_duration`-Flow
2. Failing Regression-Test erstellen
3. Minimalen Fix implementieren
4. Relevante Tests und CI absichern

## Umsetzung

- Root cause identifiziert in `app/javascript/controllers/datepicker_controller.js`:
  Dauer wurde relativ zu "heute" statt relativ zu `lent_at` berechnet.
- Fix umgesetzt:
  - Dauerberechnung relativ zu Startdatum (`calculateReturnDuration`)
  - Guard gegen leere/ungültige Dauerwerte beim Picker-Default
  - Konsistenter ESM-Import für Pikaday, kein CJS-Mix mehr
- Regression abgesichert:
  - `test/javascript/datepicker_duration_test.mjs`
  - CI-Step ergänzt in `.github/workflows/test.yml`

## Verifikation

- `node test/javascript/datepicker_duration_test.mjs` ✅
- `mise exec -- bundle exec rails test test/controllers/lending_controller_test.rb test/models/lending_test.rb` ✅
- PR checks (`build`, `test`) ✅

## Deliverables

- PR: https://github.com/bonanzahq/bonanza/pull/263
- Zugehöriger CI-Flake als Folge-Bug erfasst: #264 / git-bug `ab6f1db`
