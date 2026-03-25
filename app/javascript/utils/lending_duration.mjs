// ABOUTME: Computes the lending duration (in days) from a start date to a selected return date.
// ABOUTME: Used by the datepicker controller to write the correct value into the form's duration field.

import dayjs from 'dayjs';

/**
 * Returns the number of days between startDate and selectedDate.
 * The server stores duration as: lent_at + duration = return date.
 *
 * @param {Date}   selectedDate - The return date the user picked in the calendar.
 * @param {string} startDate    - The lending start date as a 'YYYY-MM-DD' string.
 * @returns {number}
 */
export function calculateReturnDuration(selectedDate, startDate) {
  return dayjs(selectedDate).diff(dayjs(startDate, 'YYYY-MM-DD'), 'day');
}
