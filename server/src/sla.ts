const PAKISTAN_OFFSET_MS = 5 * 60 * 60 * 1000;
const OPEN_MIN = 6 * 60;
const CLOSE_MIN = 22 * 60;

function localMinutes(utcMs: number): number {
  const local = new Date(utcMs + PAKISTAN_OFFSET_MS);
  return local.getUTCHours() * 60 + local.getUTCMinutes();
}

/** Add hours, pausing the clock from 10:00 pm to 6:00 am Pakistan time when asked. */
export function addWorkingHours(start: Date, hours: number, pauseOvernight: boolean): Date {
  if (!pauseOvernight || hours <= 0) {
    return new Date(start.getTime() + hours * 60 * 60 * 1000);
  }
  let utc = start.getTime();
  let remaining = Math.round(hours * 60);
  for (let guard = 0; guard < 20000 && remaining > 0; guard += 1) {
    const minutes = localMinutes(utc);
    if (minutes < OPEN_MIN) {
      utc += (OPEN_MIN - minutes) * 60 * 1000;
      continue;
    }
    if (minutes >= CLOSE_MIN) {
      utc += (24 * 60 - minutes + OPEN_MIN) * 60 * 1000;
      continue;
    }
    const step = Math.min(CLOSE_MIN - minutes, remaining);
    utc += step * 60 * 1000;
    remaining -= step;
  }
  return new Date(utc);
}

export function karachiStartOfToday(now = new Date()): Date {
  const local = new Date(now.getTime() + PAKISTAN_OFFSET_MS);
  const midnightUtc = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  return new Date(midnightUtc - PAKISTAN_OFFSET_MS);
}
