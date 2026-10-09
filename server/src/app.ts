import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import cors from 'cors';
import express, { type NextFunction, type Request, type Response } from 'express';
import multer from 'multer';
import { z, ZodError } from 'zod';
import type { AppConfig } from './config.js';
import type { Db } from './db.js';
import { ApiError } from './errors.js';
import { haversineKm } from './geo.js';
import { maskPhone, normalizePhone } from './phone.js';
import { hashPassword, verifyPassword } from './passwords.js';
import { OtpStore } from './otp.js';
import { karachiStartOfToday } from './sla.js';
import { issueSession, publicUser, readUser, rotateRefresh } from './session.js';
import type { UserRecord } from './types.js';
import {
  acceptCase,
  assignCase,
  confirmCase,
  createCase,
  duplicateCase,
  listMine,
  mapPins,
  mediaPath,
  mediaSignatureOk,
  noteCase,
  officerJobs,
  presentCase,
  rejectCase,
  reopenCase,
  resolveCase,
  startCase,
  zoneCases,
  zoneOfficers,
} from './cases.js';
import { mountHrAttendance } from './hr-attendance.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

function imageExt(buf: Buffer): 'jpg' | 'png' | 'webp' | null {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.length >= 8 && buf[0] === 0x89 && buf.toString('ascii', 1, 4) === 'PNG') return 'png';
  if (buf.length >= 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  return null;
}

function parse<T>(schema: z.ZodType<T>, value: unknown): T {
  const result = schema.safeParse(value);
  if (!result.success) {
    throw new ApiError(400, 'VALIDATION', result.error.issues[0]?.message ?? 'Check the form and try again.');
  }
  return result.data;
}

function hitLimit(bucket: Map<string, number[]>, key: string, limit: number, windowMs: number, message: string) {
  const now = Date.now();
  const recent = (bucket.get(key) ?? []).filter((at) => now - at < windowMs);
  if (recent.length >= limit) throw new ApiError(429, 'RATE_LIMIT', message);
  recent.push(now);
  bucket.set(key, recent);
}

export function createApp(db: Db, config: AppConfig) {
  const app = express();
  const otp = new OtpStore(config.devOtp);
  const loginHits = new Map<string, number[]>();
  app.disable('x-powered-by');
  app.use(cors({ origin: config.corsOrigin === '*' ? true : config.corsOrigin.split(',') }));
  app.use(express.json({ limit: '1mb' }));
  app.use((_req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    next();
  });

  const guard =
    (roles: UserRecord['role'][] | null, handler: (req: Request & { user: UserRecord }, res: Response) => Promise<unknown>) =>
    (req: Request, res: Response, next: NextFunction) => {
      Promise.resolve()
        .then(async () => {
          const user = await readUser(db, config, req);
          if (roles && !roles.includes(user.role)) throw new ApiError(403, 'FORBIDDEN', 'You cannot do that.');
          const body = await handler(Object.assign(req, { user }), res);
          if (body !== undefined && !res.headersSent) res.json(body);
        })
        .catch(next);
    };

  app.get('/', (_req, res) => {
    res.json({ name: 'CDA-Clean Islamabad', health: '/api/v1/health' });
  });

  app.get('/api/v1/health', (_req, res) => {
    res.json({ ok: true, service: 'cda-clean-islamabad', devOtp: !config.isProd });
  });

  app.post('/api/v1/auth/otp/request', async (req, res, next) => {
    try {
      const body = parse(z.object({ phone: z.string() }), req.body);
      const phone = normalizePhone(body.phone);
      const code = otp.request(phone);
      if (!config.isProd) console.log(`[cda-clean] OTP for ${phone} is ${code}`);
      res.status(202).json({ accepted: true });
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/v1/auth/otp/verify', async (req, res, next) => {
    try {
      const body = parse(
        z.object({
          phone: z.string(),
          code: z.string().trim().min(4),
          fullName: z.string().trim().min(2).max(80).optional(),
        }),
        req.body,
      );
      const phone = normalizePhone(body.phone);
      otp.verify(phone, body.code);
      let users = await db.query<UserRecord>(`SELECT * FROM users WHERE phone_e164 = $1`, [phone]);
      let user = users.rows[0];
      if (!user) {
        if (!body.fullName) throw new ApiError(400, 'NAME_REQUIRED', 'Enter your name to create an account.');
        const id = randomUUID();
        await db.query(
          `INSERT INTO users (id, role, full_name, phone_e164, language) VALUES ($1, 'citizen', $2, $3, 'en')`,
          [id, body.fullName, phone],
        );
        users = await db.query<UserRecord>(`SELECT * FROM users WHERE id = $1`, [id]);
        user = users.rows[0];
      }
      if (!user || user.status !== 'active') throw new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
      if (user.role !== 'citizen') {
        throw new ApiError(400, 'USE_STAFF_LOGIN', 'Staff accounts sign in with an employee ID.');
      }
      res.json(await issueSession(db, config, user));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/v1/auth/staff/login', async (req, res, next) => {
    try {
      hitLimit(loginHits, req.ip || 'local', 10, 15 * 60 * 1000, 'Too many sign-in attempts. Wait a few minutes.');
      const body = parse(
        z.object({ employeeId: z.string().trim().min(3), password: z.string().min(1) }),
        req.body,
      );
      const { rows } = await db.query<UserRecord>(
        `SELECT * FROM users WHERE UPPER(employee_id) = UPPER($1)`,
        [body.employeeId],
      );
      const user = rows[0];
      const passwordOk = user ? await verifyPassword(body.password, user.password_hash) : false;
      if (!user || !passwordOk) throw new ApiError(401, 'INVALID_LOGIN', 'Employee ID or password is wrong.');
      if (user.status !== 'active') throw new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
      if (config.isProd) {
        const code = otp.request(user.phone_e164);
        console.log(`[cda-clean] Staff OTP for ${user.employee_id} sent`);
        if (process.env.LOG_OTP === 'true') console.log(`[cda-clean] OTP for ${user.phone_e164} is ${code}`);
        res.json({ otpRequired: true, phoneHint: maskPhone(user.phone_e164) });
        return;
      }
      res.json(await issueSession(db, config, user));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/v1/auth/staff/verify', async (req, res, next) => {
    try {
      const body = parse(
        z.object({ employeeId: z.string().trim().min(3), code: z.string().trim().min(4) }),
        req.body,
      );
      const { rows } = await db.query<UserRecord>(
        `SELECT * FROM users WHERE UPPER(employee_id) = UPPER($1)`,
        [body.employeeId],
      );
      const user = rows[0];
      if (!user) throw new ApiError(401, 'INVALID_OTP', 'That code is not valid.');
      otp.verify(user.phone_e164, body.code);
      if (user.status !== 'active') throw new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
      res.json(await issueSession(db, config, user));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/v1/auth/refresh', async (req, res, next) => {
    try {
      const body = parse(z.object({ refreshToken: z.string().min(10) }), req.body);
      res.json(await rotateRefresh(db, config, body.refreshToken));
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/v1/auth/logout', guard(null, async (req) => {
    const body = parse(z.object({ refreshToken: z.string().min(10) }), req.body);
    const { createHash } = await import('node:crypto');
    const tokenHash = createHash('sha256').update(body.refreshToken).digest('hex');
    await db.query(
      `UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1 AND user_id = $2 AND revoked_at IS NULL`,
      [tokenHash, req.user.id],
    );
    return { ok: true };
  }));

  app.get('/api/v1/me', guard(null, async (req) => publicUser(req.user)));

  app.patch('/api/v1/me', guard(null, async (req) => {
    const body = parse(
      z.object({
        fullName: z.string().trim().min(2).max(80).optional(),
        sectorId: z.string().uuid().nullable().optional(),
        language: z.enum(['en', 'ur']).optional(),
      }),
      req.body,
    );
    if (body.sectorId) {
      const sector = await db.query(`SELECT id FROM sectors WHERE id = $1`, [body.sectorId]);
      if (!sector.rows[0]) throw new ApiError(400, 'SECTOR_INVALID', 'Choose a sector.');
    }
    await db.query(
      `UPDATE users
       SET full_name = COALESCE($2, full_name),
           sector_id = COALESCE($3, sector_id),
           language = COALESCE($4, language)
       WHERE id = $1`,
      [req.user.id, body.fullName ?? null, body.sectorId ?? null, body.language ?? null],
    );
    const { rows } = await db.query<UserRecord>(`SELECT * FROM users WHERE id = $1`, [req.user.id]);
    return publicUser(rows[0]);
  }));

  app.get('/api/v1/categories', guard(null, async () => {
    const { rows } = await db.query(
      `SELECT id, code, name_en, name_ur, ack_hours, resolve_hours, pause_overnight
       FROM categories WHERE active = TRUE ORDER BY name_en`,
    );
    return rows.map((row) => ({
      id: row.id,
      code: row.code,
      nameEn: row.name_en,
      nameUr: row.name_ur,
      ackHours: row.ack_hours,
      resolveHours: row.resolve_hours,
      pauseOvernight: row.pause_overnight,
    }));
  }));

  app.get('/api/v1/zones', guard(null, async (req) => {
    if (req.user.role === 'citizen') throw new ApiError(403, 'FORBIDDEN', 'Zones are visible to CDA staff.');
    const { rows } = await db.query(`SELECT id, name, code FROM zones WHERE active = TRUE ORDER BY name`);
    return rows.map((row) => ({ id: row.id, name: row.name, code: row.code }));
  }));

  app.get('/api/v1/sectors', guard(null, async (req) => {
    const params: unknown[] = [];
    let sql = `SELECT id, zone_id, name, code, center_lat, center_lng FROM sectors`;
    if (typeof req.query.zoneId === 'string') {
      params.push(req.query.zoneId);
      sql += ` WHERE zone_id = $1`;
    }
    sql += ` ORDER BY code`;
    const { rows } = await db.query(sql, params);
    return rows.map((row) => ({
      id: row.id,
      zoneId: row.zone_id,
      name: row.name,
      code: row.code,
      centerLat: Number(row.center_lat),
      centerLng: Number(row.center_lng),
    }));
  }));

  app.get('/api/v1/sectors/lookup', guard(null, async (req) => {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new ApiError(400, 'VALIDATION', 'A map pin is required.');
    }
    const { rows } = await db.query(
      `SELECT id, zone_id, name, code, center_lat, center_lng, min_lat, max_lat, min_lng, max_lng FROM sectors`,
    );
    const inside = rows.filter((sector) => {
      return lat >= Number(sector.min_lat) && lat <= Number(sector.max_lat) && lng >= Number(sector.min_lng) && lng <= Number(sector.max_lng);
    });
    const pool = inside.length ? inside : rows;
    pool.sort(
      (a, b) =>
        haversineKm(lat, lng, Number(a.center_lat), Number(a.center_lng)) -
        haversineKm(lat, lng, Number(b.center_lat), Number(b.center_lng)),
    );
    const best = pool[0];
    if (!best) return null;
    if (!inside.length && haversineKm(lat, lng, Number(best.center_lat), Number(best.center_lng)) > 3) return null;
    return { id: best.id, zoneId: best.zone_id, name: best.name, code: best.code };
  }));

  app.get('/api/v1/schedule', guard(null, async (req) => {
    const sectorId = typeof req.query.sectorId === 'string' ? req.query.sectorId : req.user.sector_id;
    if (!sectorId) throw new ApiError(400, 'SECTOR_REQUIRED', 'Choose your sector first.');
    const sector = await db.query(`SELECT id, code, name FROM sectors WHERE id = $1`, [sectorId]);
    if (!sector.rows[0]) throw new ApiError(404, 'SECTOR_INVALID', 'That sector was not found.');
    const streets = await db.query(
      `SELECT id, name, collection_days, window_start, window_end FROM streets WHERE sector_id = $1 ORDER BY name`,
      [sectorId],
    );
    const items = streets.rows.map((row) => ({
      id: row.id,
      name: row.name,
      days: String(row.collection_days).split(',').map((day) => Number(day)),
      windowStart: row.window_start,
      windowEnd: row.window_end,
    }));
    const daySet = new Set(items.flatMap((item) => item.days));
    return {
      sector: { id: sector.rows[0].id, code: sector.rows[0].code, name: sector.rows[0].name },
      days: [...daySet].sort(),
      streets: items,
    };
  }));

  app.post(
    '/api/v1/media',
    upload.single('file'),
    guard(null, async (req, res) => {
      const kind = String(req.body?.kind ?? 'before');
      if (!['before', 'after', 'reopen'].includes(kind)) {
        throw new ApiError(400, 'VALIDATION', 'Photo kind is invalid.');
      }
      if (!req.file) throw new ApiError(400, 'PHOTO_REQUIRED', 'Choose a photo.');
      const ext = imageExt(req.file.buffer);
      if (!ext) throw new ApiError(400, 'PHOTO_TYPE', 'Use a JPEG, PNG, or WebP photo.');
      const id = randomUUID();
      await mkdir(config.uploadDir, { recursive: true });
      const storageKey = `${id}.${ext}`;
      await writeFile(path.join(config.uploadDir, storageKey), req.file.buffer);
      await db.query(
        `INSERT INTO case_photos (id, kind, storage_key, uploaded_by) VALUES ($1, $2, $3, $4)`,
        [id, kind, storageKey, req.user.id],
      );
      res.status(201).json({ id, path: mediaPath(config.mediaSecret, id) });
    }),
  );

  app.get('/api/v1/media/:id/file', async (req, res, next) => {
    try {
      const exp = String(req.query.exp ?? '');
      const sig = String(req.query.sig ?? '');
      if (!mediaSignatureOk(config.mediaSecret, req.params.id, exp, sig)) {
        throw new ApiError(403, 'FORBIDDEN', 'This photo link has expired.');
      }
      const { rows } = await db.query<{ storage_key: string }>(
        `SELECT storage_key FROM case_photos WHERE id = $1`,
        [req.params.id],
      );
      if (!rows[0]) throw new ApiError(404, 'PHOTO_NOT_FOUND', 'That photo was not found.');
      const filePath = path.join(config.uploadDir, path.basename(rows[0].storage_key));
      const bytes = await readFile(filePath);
      const ext = path.extname(filePath).toLowerCase();
      const type = ext === '.png' ? 'image/png' : ext === '.webp' ? 'image/webp' : 'image/jpeg';
      res.setHeader('Content-Type', type);
      res.setHeader('Cache-Control', 'private, max-age=300');
      res.send(bytes);
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/v1/cases', guard(['citizen'], async (req, res) => {
    const body = parse(
      z.object({
        categoryId: z.string().uuid(),
        sectorId: z.string().uuid(),
        latitude: z.number(),
        longitude: z.number(),
        streetText: z.string().trim().min(2, 'Add a street or landmark.').max(200),
        description: z.string().trim().max(500).optional().default(''),
        photoIds: z.array(z.string().uuid()).min(1).max(3),
      }),
      req.body,
    );
    const created = await createCase(db, config, req.user, { ...body, description: body.description ?? '' });
    res.status(201).json(created);
  }));

  app.get('/api/v1/cases', guard(['citizen'], async (req) => {
    const status = typeof req.query.status === 'string' ? req.query.status : undefined;
    return listMine(db, config, req.user, status);
  }));

  app.get('/api/v1/cases/map', guard(['citizen'], async (req) => {
    const sectorId = typeof req.query.sectorId === 'string' ? req.query.sectorId : req.user.sector_id;
    if (!sectorId) throw new ApiError(400, 'SECTOR_REQUIRED', 'Choose your sector first.');
    return mapPins(db, sectorId);
  }));

  app.get('/api/v1/cases/:id', guard(null, async (req) => presentCase(db, req.params.id, req.user, config.mediaSecret)));

  app.post('/api/v1/cases/:id/accept', guard(['zone_supervisor'], async (req) => acceptCase(db, config, req.user, req.params.id)));
  app.post('/api/v1/cases/:id/reject', guard(['zone_supervisor'], async (req) => {
    const body = parse(z.object({ reason: z.string().trim().min(3, 'Add a short reason.') }), req.body);
    return rejectCase(db, config, req.user, req.params.id, body.reason);
  }));
  app.post('/api/v1/cases/:id/duplicate', guard(['zone_supervisor'], async (req) => {
    const body = parse(
      z.object({
        originalCaseId: z.string().uuid().optional(),
        originalCaseNumber: z.string().trim().min(4).optional(),
      }),
      req.body,
    );
    return duplicateCase(db, config, req.user, req.params.id, body);
  }));
  app.post('/api/v1/cases/:id/assign', guard(['zone_supervisor'], async (req) => {
    const body = parse(z.object({ officerId: z.string().uuid() }), req.body);
    return assignCase(db, config, req.user, req.params.id, body.officerId);
  }));
  app.post('/api/v1/cases/:id/start', guard(['field_officer'], async (req) => startCase(db, config, req.user, req.params.id)));
  app.post('/api/v1/cases/:id/note', guard(['field_officer', 'zone_supervisor'], async (req) => {
    const body = parse(z.object({ note: z.string().trim().min(1).max(500) }), req.body);
    return noteCase(db, config, req.user, req.params.id, body.note);
  }));
  app.post('/api/v1/cases/:id/resolve', guard(['field_officer'], async (req) => {
    const body = parse(
      z.object({ photoId: z.string().uuid(), note: z.string().trim().max(500).optional() }),
      req.body,
    );
    return resolveCase(db, config, req.user, req.params.id, body.photoId, body.note);
  }));
  app.post('/api/v1/cases/:id/confirm', guard(['citizen'], async (req) => confirmCase(db, config, req.user, req.params.id)));
  app.post('/api/v1/cases/:id/reopen', guard(['citizen'], async (req) => {
    const body = parse(
      z.object({
        note: z.string().trim().min(3, 'Say what is still there.'),
        photoId: z.string().uuid(),
      }),
      req.body,
    );
    return reopenCase(db, config, req.user, req.params.id, body.note, body.photoId);
  }));

  app.get('/api/v1/zone/cases', guard(['zone_supervisor'], async (req) => {
    return zoneCases(
      db,
      config,
      req.user,
      typeof req.query.bucket === 'string' ? req.query.bucket : undefined,
      typeof req.query.q === 'string' ? req.query.q : undefined,
    );
  }));
  app.get('/api/v1/zone/officers', guard(['zone_supervisor'], async (req) => zoneOfficers(db, req.user)));
  app.get('/api/v1/jobs', guard(['field_officer'], async (req) => {
    const lat = req.query.lat == null ? undefined : Number(req.query.lat);
    const lng = req.query.lng == null ? undefined : Number(req.query.lng);
    return officerJobs(
      db,
      config,
      req.user,
      Number.isFinite(lat) ? lat : undefined,
      Number.isFinite(lng) ? lng : undefined,
    );
  }));

  app.get('/api/v1/notifications', guard(null, async (req) => {
    const { rows } = await db.query(
      `SELECT id, case_id, title, body, read_at, created_at
       FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [req.user.id],
    );
    return rows.map((row) => ({
      id: row.id,
      caseId: row.case_id,
      title: row.title,
      body: row.body,
      readAt: row.read_at ? new Date(String(row.read_at)).toISOString() : null,
      createdAt: new Date(String(row.created_at)).toISOString(),
    }));
  }));

  app.post('/api/v1/notifications/:id/read', guard(null, async (req) => {
    await db.query(`UPDATE notifications SET read_at = NOW() WHERE id = $1 AND user_id = $2`, [
      req.params.id,
      req.user.id,
    ]);
    return { ok: true };
  }));

  app.post('/api/v1/devices', guard(null, async (req) => {
    const body = parse(
      z.object({ fcmToken: z.string().min(8), platform: z.enum(['android', 'ios', 'web']) }),
      req.body,
    );
    await db.query(
      `INSERT INTO device_tokens (token, user_id, platform, updated_at) VALUES ($1, $2, $3, NOW())
       ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW()`,
      [body.fcmToken, req.user.id, body.platform],
    );
    return { ok: true };
  }));

  const admin = ['directorate_admin', 'system_admin'] as const;

  app.get('/api/v1/dashboard/city', guard([...admin], async () => cityStats(db, null)));
  app.get('/api/v1/dashboard/zone/:zoneId', guard(null, async (req) => {
    const zoneId = req.params.zoneId;
    const allowed =
      req.user.role === 'directorate_admin' ||
      req.user.role === 'system_admin' ||
      (req.user.role === 'zone_supervisor' && req.user.zone_id === zoneId);
    if (!allowed) throw new ApiError(403, 'FORBIDDEN', 'That zone is outside your office.');
    return cityStats(db, zoneId);
  }));

  app.get('/api/v1/admin/cases', guard([...admin], async (req) => {
    const params: unknown[] = [];
    let sql = `SELECT c.id, c.case_number, c.status, c.created_at, s.code AS sector_code, cat.name_en, z.name AS zone_name
               FROM cases c
               JOIN sectors s ON s.id = c.sector_id
               JOIN categories cat ON cat.id = c.category_id
               JOIN zones z ON z.id = c.zone_id`;
    if (typeof req.query.zoneId === 'string') {
      params.push(req.query.zoneId);
      sql += ` WHERE c.zone_id = $1`;
    }
    sql += ` ORDER BY c.created_at DESC LIMIT 50`;
    const { rows } = await db.query(sql, params);
    return rows.map((row) => ({
      id: row.id,
      caseNumber: row.case_number,
      status: row.status,
      sectorCode: row.sector_code,
      categoryName: row.name_en,
      zoneName: row.zone_name,
      createdAt: new Date(String(row.created_at)).toISOString(),
    }));
  }));

  app.get('/api/v1/admin/cases/export', guard([...admin], async (req, res) => {
    const from = typeof req.query.from === 'string' ? new Date(req.query.from) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const to = typeof req.query.to === 'string' ? new Date(req.query.to) : new Date();
    const { rows } = await db.query(
      `SELECT c.case_number, s.code AS sector_code, cat.name_en, c.status, c.created_at, c.resolved_at
       FROM cases c
       JOIN sectors s ON s.id = c.sector_id
       JOIN categories cat ON cat.id = c.category_id
       WHERE c.created_at >= $1 AND c.created_at <= $2
       ORDER BY c.created_at`,
      [from, to],
    );
    const header = 'case_number,sector,category,status,created_at,resolved_at';
    const lines = rows.map((row) =>
      [row.case_number, row.sector_code, row.name_en, row.status, isoCsv(row.created_at), isoCsv(row.resolved_at)]
        .map(csvCell)
        .join(','),
    );
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.send([header, ...lines].join('\n'));
  }));

  app.get('/api/v1/admin/staff', guard([...admin], async () => staffList(db)));
  app.post('/api/v1/admin/staff', guard([...admin], async (req, res) => {
    const body = parse(
      z.object({
        fullName: z.string().trim().min(2).max(80),
        employeeId: z.string().trim().min(3).max(20),
        phone: z.string(),
        role: z.enum(['field_officer', 'zone_supervisor']),
        zoneId: z.string().uuid(),
        password: z.string().min(8).max(72),
      }),
      req.body,
    );
    const phone = normalizePhone(body.phone);
    const zone = await db.query(`SELECT id FROM zones WHERE id = $1`, [body.zoneId]);
    if (!zone.rows[0]) throw new ApiError(400, 'ZONE_INVALID', 'Choose a zone.');
    const id = randomUUID();
    const passwordHash = await hashPassword(body.password);
    try {
      await db.query(
        `INSERT INTO users (id, role, full_name, phone_e164, employee_id, password_hash, zone_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [id, body.role, body.fullName, phone, body.employeeId.toUpperCase(), passwordHash, body.zoneId],
      );
    } catch {
      throw new ApiError(409, 'STAFF_EXISTS', 'That employee ID or phone is already in use.');
    }
    await db.query(
      `INSERT INTO audit_log (id, actor_id, action, entity, entity_id, payload) VALUES ($1, $2, 'create', 'user', $3, $4::jsonb)`,
      [randomUUID(), req.user.id, id, JSON.stringify({ role: body.role, zoneId: body.zoneId })],
    );
    res.status(201).json({ id });
  }));

  app.patch('/api/v1/admin/staff/:id', guard([...admin], async (req) => {
    const body = parse(z.object({ status: z.enum(['active', 'disabled']) }), req.body);
    const { rowCount } = await db.query(`UPDATE users SET status = $2 WHERE id = $1 AND role <> 'citizen'`, [
      req.params.id,
      body.status,
    ]);
    if (!rowCount) throw new ApiError(404, 'STAFF_NOT_FOUND', 'That staff account was not found.');
    await db.query(
      `INSERT INTO audit_log (id, actor_id, action, entity, entity_id, payload) VALUES ($1, $2, 'status', 'user', $3, $4::jsonb)`,
      [randomUUID(), req.user.id, req.params.id, JSON.stringify({ status: body.status })],
    );
    return { ok: true };
  }));

  mountHrAttendance(app, config);

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof ZodError) {
      res.status(400).json({ error: { code: 'VALIDATION', message: error.issues[0]?.message ?? 'Check the form and try again.' } });
      return;
    }
    if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
      res.status(400).json({ error: { code: 'PHOTO_TOO_LARGE', message: 'Photos must be under 5 MB.' } });
      return;
    }
    if (error instanceof ApiError) {
      res.status(error.status).json({ error: { code: error.code, message: error.message } });
      return;
    }
    if (error instanceof Error && 'code' in error && (error as NodeJS.ErrnoException).code === 'ENOENT') {
      res.status(404).json({ error: { code: 'PHOTO_NOT_FOUND', message: 'That photo file is missing.' } });
      return;
    }
    console.error(error);
    res.status(500).json({ error: { code: 'INTERNAL', message: 'Something went wrong. Try again.' } });
  });

  return app;
}

function csvCell(value: unknown): string {
  const text = value == null ? '' : String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function isoCsv(value: unknown): string {
  if (value == null) return '';
  const date = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
}

async function cityStats(db: Db, zoneId: string | null) {
  const params: unknown[] = [];
  let where = '';
  if (zoneId) {
    params.push(zoneId);
    where = `WHERE zone_id = $1`;
  }
  const { rows } = await db.query(
    `SELECT status, sla_breached, ack_breached, created_at, resolved_at FROM cases ${where}`,
    params,
  );
  const start = karachiStartOfToday();
  const open = rows.filter((row) => !['closed', 'rejected', 'duplicate'].includes(String(row.status)));
  const breached = open.filter((row) => row.sla_breached || row.ack_breached);
  const filedToday = rows.filter((row) => new Date(String(row.created_at)).getTime() >= start.getTime());
  const monthAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
  const hours = rows
    .filter((row) => row.resolved_at && new Date(String(row.resolved_at)).getTime() >= monthAgo)
    .map((row) => (new Date(String(row.resolved_at)).getTime() - new Date(String(row.created_at)).getTime()) / 36e5)
    .sort((a, b) => a - b);
  const mid = Math.floor(hours.length / 2);
  const medianHours = hours.length === 0 ? null : hours.length % 2 ? hours[mid] : (hours[mid - 1] + hours[mid]) / 2;
  const zones = await db.query(
    `SELECT z.id, z.name, z.code,
            COUNT(c.id) FILTER (WHERE c.status NOT IN ('closed', 'rejected', 'duplicate')) AS open_cases
     FROM zones z
     LEFT JOIN cases c ON c.zone_id = z.id
     GROUP BY z.id, z.name, z.code
     ORDER BY z.name`,
  );
  return {
    openCases: open.length,
    breached: breached.length,
    filedToday: filedToday.length,
    medianResolveHours: medianHours == null ? null : Math.round(medianHours * 10) / 10,
    zones: zones.rows.map((row) => ({
      id: row.id,
      name: row.name,
      code: row.code,
      openCases: Number(row.open_cases),
    })),
  };
}

async function staffList(db: Db) {
  const { rows } = await db.query(
    `SELECT u.id, u.full_name, u.employee_id, u.phone_e164, u.role, u.status, u.zone_id, z.name AS zone_name
     FROM users u
     LEFT JOIN zones z ON z.id = u.zone_id
     WHERE u.role <> 'citizen'
     ORDER BY u.full_name`,
  );
  return rows.map((row) => ({
    id: row.id,
    fullName: row.full_name,
    employeeId: row.employee_id,
    phone: row.phone_e164,
    role: row.role,
    status: row.status,
    zoneId: row.zone_id,
    zoneName: row.zone_name,
  }));
}
