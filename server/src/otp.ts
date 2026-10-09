import { createHash, randomInt, timingSafeEqual } from 'node:crypto';
import { ApiError } from './errors.js';

type Challenge = {
  hash: string;
  attempts: number;
  expiresAt: number;
  lockedUntil: number;
};

export class OtpStore {
  private challenges = new Map<string, Challenge>();
  private requests = new Map<string, number[]>();

  constructor(private readonly devCode: string | null) {}

  request(phone: string): string {
    const now = Date.now();
    const recent = (this.requests.get(phone) ?? []).filter((at) => now - at < 60 * 60 * 1000);
    if (recent.length >= 5) {
      throw new ApiError(429, 'RATE_LIMIT', 'Wait before requesting another code.');
    }
    recent.push(now);
    this.requests.set(phone, recent);

    const current = this.challenges.get(phone);
    if (current && current.lockedUntil > now) {
      return this.devCode ?? '******';
    }
    const code = this.devCode ?? String(randomInt(0, 1_000_000)).padStart(6, '0');
    this.challenges.set(phone, {
      hash: this.hash(code),
      attempts: 0,
      expiresAt: now + 5 * 60 * 1000,
      lockedUntil: 0,
    });
    return code;
  }

  verify(phone: string, code: string): void {
    const now = Date.now();
    const current = this.challenges.get(phone);
    if (!current || current.expiresAt < now) {
      throw new ApiError(401, 'INVALID_OTP', 'That code is not valid. Request a new one.');
    }
    if (current.lockedUntil > now) {
      throw new ApiError(429, 'OTP_LOCKED', 'Too many attempts. Try again in 15 minutes.');
    }
    const given = this.hash(code.trim());
    const a = Buffer.from(given);
    const b = Buffer.from(current.hash);
    const match = a.length === b.length && timingSafeEqual(a, b);
    if (!match) {
      current.attempts += 1;
      if (current.attempts >= 5) current.lockedUntil = now + 15 * 60 * 1000;
      throw new ApiError(401, 'INVALID_OTP', 'That code is not valid. Request a new one.');
    }
    this.challenges.delete(phone);
  }

  private hash(code: string): string {
    return createHash('sha256').update(`cda-otp:${code}`).digest('hex');
  }
}
