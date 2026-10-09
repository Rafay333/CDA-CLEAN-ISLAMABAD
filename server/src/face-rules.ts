// Distances and liveness match AttendanceSystem\Server\Program.cs.

export function faceDistance(a: number[], b: number[]): number {
  let sum = 0;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    const d = a[i] - b[i];
    sum += d * d;
  }
  return Math.sqrt(sum);
}

export function identify(bank: Map<number, number[][]>, probes: number[][], exclude = -1) {
  let id = -1;
  let best = Number.POSITIVE_INFINITY;
  let second = Number.POSITIVE_INFINITY;
  for (const [employeeId, known] of bank) {
    if (employeeId === exclude || known.length === 0) continue;
    let distance = Number.POSITIVE_INFINITY;
    for (const saved of known) {
      for (const probe of probes) distance = Math.min(distance, faceDistance(saved, probe));
    }
    if (distance < best) {
      second = best;
      best = distance;
      id = employeeId;
    } else if (distance < second) second = distance;
  }
  return { id, best, second };
}

export function samePerson(encodings: number[][]): boolean {
  for (let i = 0; i < encodings.length; i++) {
    for (let j = i + 1; j < encodings.length; j++) {
      if (faceDistance(encodings[i], encodings[j]) > 0.45) return false;
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
