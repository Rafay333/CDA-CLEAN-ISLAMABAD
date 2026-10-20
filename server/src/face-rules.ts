// Liveness rules match AttendanceSystem\Server\Program.cs. The identification rule is
// stricter than that project: see identify() below.

// Attendance: a person is recognised when the agreed distance is at or under this value.
// Glasses, a mustache, or a beard move the same person by about 0.1, so this sits a little
// above a clean match and still under a typical different person.
// Stricter than dlib’s 0.6 default; still allows ~0.10 shift for glasses/beard on the
// same worker when three HD enrolment encodings are stored (dlib recommends calibrating).
// Aligns with phone minAcceptMatchPercent 60 → distance 0.40.
export const recogniseDistance = 0.4;
// Attendance: the best person must beat the runner-up by at least this much, or we refuse
// to guess between two look-alikes (two men with beards, for example).
export const recogniseMargin = 0.12;
// Enrolment: the three registration photos must all be this close to each other. Wide enough
// for one photo with glasses off, or with the mustache / beard looking different.
export const enrolSameFaceDistance = 0.6;
// Enrolment: block a second record only when ALL three new photos look like the stored
// face (max per-probe distance, not median). Median + 0.40 still flagged a colleague who
// shares a beard. Same person twice lands well under this; Jawad vs Abdul Rafay does not.
export const duplicateFaceDistance = 0.32;
// Both: the detected face must be at least this many pixels wide. Small faces give blurry
// encodings that drift towards everybody else, which is how a stranger gets matched.
export const minFaceSize = 120;

export function faceDistance(a: number[], b: number[]): number {
  let sum = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    const d = a[i] - b[i];
    sum += d * d;
  }
  return Math.sqrt(sum);
}

function median(values: number[]): number {
  if (values.length === 0) return Number.POSITIVE_INFINITY;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/**
 * Distance between one employee's saved encodings and a burst of probe encodings.
 *
 * For every probe we take its closest saved encoding, then take the MEDIAN over probes.
 * With three probes that means at least two of the three pictures must agree. The old
 * rule took the single smallest of all 3x3 distances, so one lucky frame was enough to
 * match a stranger.
 */
function perProbeClosest(known: number[][], probes: number[][]): number[] {
  return probes.map((probe) => {
    let d = Number.POSITIVE_INFINITY;
    for (const saved of known) d = Math.min(d, faceDistance(saved, probe));
    return d;
  });
}

export function personDistance(known: number[][], probes: number[][]): number {
  return median(perProbeClosest(known, probes));
}

/** All three new photos must look like the stored person before we call it a duplicate. */
export function duplicatePersonDistance(known: number[][], probes: number[][]): number {
  const perProbe = perProbeClosest(known, probes);
  if (perProbe.length === 0) return Number.POSITIVE_INFINITY;
  return Math.max(...perProbe);
}

export function findDuplicate(bank: Map<number, number[][]>, probes: number[][], exclude = -1) {
  let id = -1;
  let best = Number.POSITIVE_INFINITY;
  for (const [employeeId, known] of bank) {
    if (employeeId === exclude || known.length === 0) continue;
    const distance = duplicatePersonDistance(known, probes);
    if (distance < best) {
      best = distance;
      id = employeeId;
    }
  }
  return { id, best };
}

export function identify(bank: Map<number, number[][]>, probes: number[][], exclude = -1) {
  let id = -1;
  let best = Number.POSITIVE_INFINITY;
  let second = Number.POSITIVE_INFINITY;
  for (const [employeeId, known] of bank) {
    if (employeeId === exclude || known.length === 0) continue;
    const distance = personDistance(known, probes);
    if (distance < best) {
      second = best;
      best = distance;
      id = employeeId;
    } else if (distance < second) second = distance;
  }
  return { id, best, second };
}

/** True when the match is close enough AND clearly ahead of the runner-up. */
export function recognised(match: { id: number; best: number; second: number }): boolean {
  if (match.id < 0 || match.best > recogniseDistance) return false;
  return match.second - match.best >= recogniseMargin;
}

export function samePerson(encodings: number[][], limit = enrolSameFaceDistance): boolean {
  for (let i = 0; i < encodings.length; i++) {
    for (let j = i + 1; j < encodings.length; j++) {
      if (faceDistance(encodings[i], encodings[j]) > limit) return false;
    }
  }
  return true;
}

export function eyeDistance(points: number[]): number {
  let lx = 0;
  let ly = 0;
  let rx = 0;
  let ry = 0;
  const left = 17 + 5 + 5 + 4 + 5;
  const right = left + 6;
  for (let i = 0; i < 6; i++) {
    lx += points[2 * (left + i)];
    ly += points[2 * (left + i) + 1];
    rx += points[2 * (right + i)];
    ry += points[2 * (right + i) + 1];
  }
  return Math.sqrt((lx - rx) * (lx - rx) + (ly - ry) * (ly - ry)) / 6;
}

export function residual(a: number[], b: number[]): number {
  const n = Math.floor(a.length / 2);
  let ax = 0;
  let ay = 0;
  let bx = 0;
  let by = 0;
  for (let i = 0; i < n; i++) {
    ax += a[2 * i];
    ay += a[2 * i + 1];
    bx += b[2 * i];
    by += b[2 * i + 1];
  }
  ax /= n;
  ay /= n;
  bx /= n;
  by /= n;
  let re = 0;
  let im = 0;
  let nb = 0;
  for (let i = 0; i < n; i++) {
    const x1 = a[2 * i] - ax;
    const y1 = a[2 * i + 1] - ay;
    const x2 = b[2 * i] - bx;
    const y2 = b[2 * i + 1] - by;
    re += x1 * x2 + y1 * y2;
    im += y1 * x2 - x1 * y2;
    nb += x2 * x2 + y2 * y2;
  }
  const zr = re / nb;
  const zi = im / nb;
  let sum = 0;
  for (let i = 0; i < n; i++) {
    const x1 = a[2 * i] - ax;
    const y1 = a[2 * i + 1] - ay;
    const x2 = b[2 * i] - bx;
    const y2 = b[2 * i + 1] - by;
    const dx = x1 - (zr * x2 - zi * y2);
    const dy = y1 - (zi * x2 + zr * y2);
    sum += dx * dx + dy * dy;
  }
  return Math.sqrt(sum / n);
}

export function packDoubles(values: number[]): Buffer {
  const bytes = Buffer.alloc(values.length * 8);
  values.forEach((value, index) => bytes.writeDoubleLE(value, index * 8));
  return bytes;
}

export function unpackDoubles(bytes: Buffer): number[] {
  const values: number[] = [];
  for (let i = 0; i < bytes.length; i += 8) values.push(bytes.readDoubleLE(i));
  return values;
}

export function packEncoding(values: number[]): Buffer {
  return packDoubles(values);
}

export function unpackEncoding(bytes: Buffer): number[] {
  return unpackDoubles(bytes);
}
