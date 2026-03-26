// ABOUTME: Tests that the datepicker computes lending duration relative to start date.
// ABOUTME: Regression for #262 — changing return date by 7 days on an active lending failed.

import assert from 'node:assert/strict';
import dayjs from 'dayjs';
import {
  calculateReturnDuration,
  calculatePickerDate
} from '../../app/javascript/utils/lending_duration.mjs';

// Scenario: lending started 10 days ago, user picks a date 7 days from now.
// The computed duration must be relative to the lending start date so that
// lent_at + duration lands on the selected date (in the future), not today.

const START_DATE = '2026-03-15'; // 10 days before the test reference date
const SELECTED = new Date('2026-04-01T12:00:00'); // 7 days after 2026-03-25

const duration = calculateReturnDuration(SELECTED, START_DATE);

// Server validates: lent_at.to_date + duration.days >= Date.today
// So duration must equal diff(SELECTED, START_DATE) = 17
assert.strictEqual(duration, 17,
  `Expected duration=17 (diff from start date), got ${duration}. ` +
  `If this is 8, the calculation used today as base instead of start date.`
);

const pickerDate = calculatePickerDate(START_DATE, '17');
assert.ok(pickerDate instanceof Date, 'Expected a Date for numeric duration values');
assert.strictEqual(dayjs(pickerDate).format('YYYY-MM-DD'), '2026-04-01');

assert.strictEqual(calculatePickerDate(START_DATE, ''), null,
  'Expected null for blank duration to avoid Invalid Date in picker init.'
);

console.log('OK');
