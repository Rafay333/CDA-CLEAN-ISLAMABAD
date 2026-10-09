import { ApiError } from './errors.js';

const ALLOWED: Record<string, string[]> = {
  submitted: ['accepted', 'rejected', 'duplicate'],
  accepted: ['assigned'],
  assigned: ['in_progress', 'assigned'],
  in_progress: ['resolved', 'assigned'],
  resolved: ['closed', 'reopened'],
  reopened: ['assigned'],
};

export function assertTransition(from: string, to: string): void {
  if (!ALLOWED[from]?.includes(to)) {
    throw new ApiError(409, 'INVALID_TRANSITION', `A report cannot move from ${from} to ${to}.`);
  }
}
