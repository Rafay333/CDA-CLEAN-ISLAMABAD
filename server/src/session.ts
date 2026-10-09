import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { Request } from 'express';
import jwt from 'jsonwebtoken';
import type { AppConfig } from './config.js';
import type { Db } from './db.js';
import { ApiError } from './errors.js';
import type { UserRecord } from './types.js';

export function publicUser(user: UserRecord) {
  return {
    id: user.id,
    role: user.role,
    fullName: user.full_name,
    phone: user.phone_e164,
    language: user.language,
    sectorId: user.sector_id,
    zoneId: user.zone_id,
    employeeId: user.employee_id,
  };
}

export async function issueSession(db: Db, config: AppConfig, user: UserRecord) {
  const accessToken = jwt.sign({ sub: user.id, role: user.role }, config.jwtAccessSecret, { expiresIn: '15m' });
  const refreshToken = randomBytes(32).toString('hex');
  const tokenHash = createHash('sha256').update(refreshToken).digest('hex');
  await db.query(
    `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)`,
    [randomUUID(), user.id, tokenHash, new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)],
  );
  return { accessToken, refreshToken, user: publicUser(user) };
}

export async function readUser(db: Db, config: AppConfig, req: Request): Promise<UserRecord> {
  const header = req.header('authorization') ?? '';
  if (!header.toLowerCase().startsWith('bearer ')) {
    throw new ApiError(401, 'UNAUTHENTICATED', 'Sign in required.');
  }
  try {
    const payload = jwt.verify(header.slice(7).trim(), config.jwtAccessSecret) as { sub?: string };
    if (!payload.sub) throw new Error('missing subject');
    const { rows } = await db.query<UserRecord>(`SELECT * FROM users WHERE id = $1`, [payload.sub]);
    const user = rows[0];
    if (!user || user.status !== 'active') {
      throw new ApiError(401, 'UNAUTHENTICATED', 'This account is not active.');
    }
    return user;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(401, 'UNAUTHENTICATED', 'Sign in required.');
  }
}

export async function rotateRefresh(db: Db, config: AppConfig, refreshToken: string) {
  const tokenHash = createHash('sha256').update(refreshToken).digest('hex');
  const { rows } = await db.query<{ id: string; user_id: string; expires_at: Date | string; revoked_at: Date | string | null }>(
    `SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = $1`,
    [tokenHash],
  );
  const row = rows[0];
  if (!row || row.revoked_at || new Date(row.expires_at).getTime() < Date.now()) {
    throw new ApiError(401, 'UNAUTHENTICATED', 'Sign in again.');
  }
  await db.query(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1`, [row.id]);
  const users = await db.query<UserRecord>(`SELECT * FROM users WHERE id = $1`, [row.user_id]);
  const user = users.rows[0];
  if (!user || user.status !== 'active') throw new ApiError(401, 'UNAUTHENTICATED', 'This account is not active.');
  return issueSession(db, config, user);
}
