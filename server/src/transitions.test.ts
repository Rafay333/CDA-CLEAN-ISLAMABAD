import assert from 'node:assert/strict';
import test from 'node:test';
import { ApiError } from './errors.js';
import { assertTransition } from './transitions.js';

test('the case lifecycle allows the documented steps', () => {
  assert.doesNotThrow(() => assertTransition('submitted', 'accepted'));
  assert.doesNotThrow(() => assertTransition('accepted', 'assigned'));
  assert.doesNotThrow(() => assertTransition('assigned', 'in_progress'));
  assert.doesNotThrow(() => assertTransition('in_progress', 'resolved'));
  assert.doesNotThrow(() => assertTransition('resolved', 'closed'));
  assert.doesNotThrow(() => assertTransition('resolved', 'reopened'));
  assert.doesNotThrow(() => assertTransition('reopened', 'assigned'));
});

test('skipping assign is rejected', () => {
  assert.throws(() => assertTransition('submitted', 'resolved'), (error: unknown) => {
    return error instanceof ApiError && error.status === 409 && error.code === 'INVALID_TRANSITION';
  });
});
