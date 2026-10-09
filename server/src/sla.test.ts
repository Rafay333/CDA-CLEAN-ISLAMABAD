import assert from 'node:assert/strict';
import test from 'node:test';
import { addWorkingHours } from './sla.js';

test('overnight complaints pause outside 6:00 to 22:00 Pakistan time', () => {
  const start = new Date('2026-10-09T16:00:00.000Z');
  const due = addWorkingHours(start, 2, true);
  assert.equal(due.toISOString(), '2026-10-10T02:00:00.000Z');
});

test('dead-animal style complaints run through the night', () => {
  const start = new Date('2026-10-09T16:00:00.000Z');
  const due = addWorkingHours(start, 12, false);
  assert.equal(due.toISOString(), '2026-10-10T04:00:00.000Z');
});
