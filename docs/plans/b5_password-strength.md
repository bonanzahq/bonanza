# B5: Password Strength Validation

## Problem Statement

Minimum password length alone is insufficient. Users can set passwords like
"password" (8 chars) which pass length validation but are trivially guessable
and appear in every breach database. NIST SP 800-63B mandates breached password
checking and recommends entropy-based scoring.

## Approach

Combine two focused gems rather than a single all-in-one solution:

- **zxcvbn** (formigarafa/zxcvbn-rb, v1.0.0) -- entropy/pattern scoring
  matching Dropbox's zxcvbn.js v4.4.2. Detects keyboard patterns, repeated
  chars, l33t substitutions, common names, dates, sequences. Supports
  user-supplied word lists for context-specific checks. ~7.2MB memory.

- **unpwn** (indirect/unpwn, v1.0.1) -- breached password checking via HIBP
  k-anonymity API. Includes local bloom filter of top 1M breached passwords
  (~1.73MB) so common weak passwords are caught without a network call. Falls
  back gracefully when API is unreachable. Used by RubyGems.org in production.

Custom ActiveModel validator (not a Devise module) since `devise_zxcvbn` is
stale and pinned to old gem versions.

## Open Questions

These need discussion before implementation:

1. **Minimum password length**: Keep at 8 (current) or increase toward NIST's
   15-char recommendation? With zxcvbn + breach checking, 8 may be sufficient
   for a university equipment lending tool.

2. **`pwned` vs `unpwn`**: Plan uses `unpwn` (bloom filter + API fallback).
   Nicer for dev/offline, used by RubyGems.org. Adds ~1.73MB memory.
   Alternative: pure `pwned` gem with API-only checking.

3. **Minimum zxcvbn score**: 3 (safely unguessable, ~10^8 guesses) vs 2
   (somewhat guessable)? Defaulting to 3.

4. **Existing weak passwords**: Only enforce on password creation/change, or
   warn/force change at next login? Forcing change is a separate feature.

5. **Client-side strength meter**: Add zxcvbn.js in the browser for real-time
   feedback? Would be a separate task.

## Implementation Plan

### Step 1: Add gems

```ruby
gem "zxcvbn", "1.0.0"
gem "unpwn", "1.0.1"
```

### Step 2: Write failing tests for password strength validation

Create `test/validators/password_strength_validator_test.rb`:

- Weak password rejected (e.g. "password1" -- low zxcvbn score, likely breached)
- Breached password rejected (e.g. "correcthorsebatterystaple" -- decent
  entropy but definitely in HIBP)
- Context-specific rejection (password containing user's email or name)
- Strong password accepted (random high-entropy string)
- Long password truncated for zxcvbn (200-char password doesn't cause
  performance issues -- only score first 100 chars)
- Blank password skipped (profile edit without password change)
- Network failure graceful degradation (HIBP unreachable, validation still
  succeeds)

Use WebMock or unpwn's test mode to avoid hitting real HIBP API.

### Step 3: Create the validator

`app/validators/password_strength_validator.rb`:

- Subclass `ActiveModel::EachValidator`
- Skip if value is blank (Devise handles presence)
- **Breach check**: Use Unpwn, rescue network failures gracefully
- **Context check**: Build user_inputs from record's email, firstname,
  lastname, and "bonanza". Pass to zxcvbn.
- **Entropy check**: `Zxcvbn.test(value[0..99], user_inputs)`, check `.score`
  against threshold (default: 3). Truncate to 100 chars for DoS mitigation.
- German error messages via I18n

### Step 4: Add German I18n keys

In `config/locales/` (wherever locale strings live):

```yaml
de:
  activerecord:
    errors:
      models:
        user:
          attributes:
            password:
              breached: "wurde in einem Datenleck gefunden und kann nicht verwendet werden"
              too_weak: "ist zu schwach -- verwende eine laengere oder ungewoehnlichere Kombination"
```

### Step 5: Wire up on User model

```ruby
validates :password, password_strength: true, if: :password
```

### Step 6: Update test passwords

Grep for weak passwords ("password", "password123", "valid123", etc.) across
all test files, fixtures, seeds, and factories. Update to strong passwords.

Check that `db/seeds.rb` seed credentials still work (they may bypass
validation or may need updating).

### Step 7: Update Devise view hints

Change password hint text from "(mindestens X Zeichen)" to something like
"(mindestens 8 Zeichen, kein bekanntes oder leicht erratbares Passwort)"
in all password fields.

### Step 8: Run full test suite

### Step 9: Update documentation

## Files to Modify

| File | Change |
|------|--------|
| `Gemfile` | Add zxcvbn and unpwn |
| `app/models/user.rb` | Add password_strength validation |
| `config/locales/*.yml` | German error messages |
| `test/models/user_test.rb` | Update password tests |
| `test/fixtures/` or factories | Update weak passwords |
| `db/seeds.rb` | Check/update seed password |
| Devise password views (4 files) | Update hint text |

## New Files

| File | Purpose |
|------|---------|
| `app/validators/password_strength_validator.rb` | Custom validator combining zxcvbn + unpwn |
| `test/validators/password_strength_validator_test.rb` | Validator tests |

## Risks

- **Seed/fixture passwords**: "password" is used everywhere in seeds and tests.
  Thorough grep needed.
- **Network in CI**: Tests must not hit real HIBP API. Need WebMock stubs or
  unpwn offline mode.
- **Memory**: ~9MB total for zxcvbn dictionaries + unpwn bloom filter. Fine
  for Rails.
- **unpwn bloom filter freshness**: Covers top 1M passwords, API handles the
  rest. If API is down, only bloom filter is checked.
