import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import type { AppConfig } from './config.js';
import type { Db } from './db.js';
import { ApiError } from './errors.js';
import { haversineKm, insideIct } from './geo.js';
import { addWorkingHours } from './sla.js';
import { assertTransition } from './transitions.js';
import type { UserRecord } from './types.js';

type CaseRow = {
  id: string;
  case_number: string;
  reporter_id: string;
  category_id: string;
  status: string;
  sector_id: string;
  zone_id: string;
  street_text: string;
  description: string;
  latitude: number | string;
  longitude: number | string;
  sector_overridden: boolean;
  ack_due_at: Date | string | null;
  sla_due_at: Date | string | null;
  ack_breached: boolean;
  sla_breached: boolean;
  duplicate_of_id: string | null;
  rejection_reason: string | null;
  resolved_at: Date | string | null;
  created_at: Date | string;
  updated_at: Date | string;
  category_code: string;
  category_name_en: string;
  category_name_ur: string;
  ack_hours: number;
  resolve_hours: number;
  pause_overnight: boolean;
  sector_code: string;
  sector_name: string;
  zone_name: string;
  zone_code: string;
  duplicate_of_number: string | null;
  reporter_name: string;
  reporter_phone: string;
  reporter_language: string;
};

type SectorRow = {
  id: string;
  zone_id: string;
  name: string;
  code: string;
  min_lat: number | string;
  max_lat: number | string;
  min_lng: number | string;
  max_lng: number | string;
  center_lat: number | string;
  center_lng: number | string;
};

const CASE_FROM = `
  FROM cases c
  JOIN categories cat ON cat.id = c.category_id
  JOIN sectors s ON s.id = c.sector_id
  JOIN zones z ON z.id = c.zone_id
  JOIN users reporter ON reporter.id = c.reporter_id
  LEFT JOIN cases dup ON dup.id = c.duplicate_of_id
`;

const CASE_SELECT = `
  SELECT c.*,
    cat.code AS category_code,
    cat.name_en AS category_name_en,
    cat.name_ur AS category_name_ur,
    cat.ack_hours,
    cat.resolve_hours,
    cat.pause_overnight,
    s.code AS sector_code,
    s.name AS sector_name,
    z.name AS zone_name,
    z.code AS zone_code,
    dup.case_number AS duplicate_of_number,
    reporter.full_name AS reporter_name,
    reporter.phone_e164 AS reporter_phone,
    reporter.language AS reporter_language
  ${CASE_FROM}
`;

function iso(value: unknown): string | null {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function num(value: number | string): number {
  return typeof value === 'number' ? value : Number(value);
}

export function mediaPath(secret: string, photoId: string): string {
  const exp = Date.now() + 15 * 60 * 1000;
  const sig = createHmac('sha256', secret).update(`${photoId}.${exp}`).digest('hex');
  return `/api/v1/media/${photoId}/file?exp=${exp}&sig=${sig}`;
}

export function mediaSignatureOk(secret: string, photoId: string, exp: string, sig: string): boolean {
  const expires = Number(exp);
  if (!Number.isFinite(expires) || expires < Date.now()) return false;
  const expected = createHmac('sha256', secret).update(`${photoId}.${exp}`).digest('hex');
  const left = Buffer.from(sig);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

function isAdmin(role: string): boolean {
  return role === 'directorate_admin' || role === 'system_admin';
}

function assertCanView(row: CaseRow, viewer: UserRecord): void {
  if (isAdmin(viewer.role)) return;
  if (viewer.role === 'citizen' && row.reporter_id === viewer.id) return;
  if ((viewer.role === 'zone_supervisor' || viewer.role === 'field_officer') && viewer.zone_id === row.zone_id) {
    return;
  }
  throw new ApiError(403, 'FORBIDDEN', 'You cannot open this report.');
}

function assertSupervisor(user: UserRecord, zoneId: string): void {
  if (user.role !== 'zone_supervisor' || user.zone_id !== zoneId) {
    throw new ApiError(403, 'FORBIDDEN', 'This report belongs to another zone.');
  }
}

export async function addEvent(
  tx: Db,
  caseId: string,
  actorId: string | null,
  from: string | null,
  to: string | null,
  note: string | null,
): Promise<void> {
  await tx.query(
    `INSERT INTO case_events (id, case_id, actor_id, from_status, to_status, note)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [randomUUID(), caseId, actorId, from, to, note],
  );
}

export async function notifyUsers(
  tx: Db,
  users: { id: string; language: string }[],
  caseId: string,
  en: { title: string; body: string },
  ur: { title: string; body: string },
): Promise<void> {
  for (const user of users) {
    const text = user.language === 'ur' ? ur : en;
    await tx.query(
      `INSERT INTO notifications (id, user_id, case_id, title, body) VALUES ($1, $2, $3, $4, $5)`,
      [randomUUID(), user.id, caseId, text.title, text.body],
    );
  }
}

export async function listSupervisors(tx: Db, zoneId: string): Promise<{ id: string; language: string }[]> {
  const { rows } = await tx.query<{ id: string; language: string }>(
    `SELECT id, language FROM users WHERE role = 'zone_supervisor' AND zone_id = $1 AND status = 'active'`,
    [zoneId],
  );
  return rows;
}

function present(row: CaseRow, viewer: UserRecord, secret: string, detail = false) {
  const body: Record<string, unknown> = {
    id: row.id,
    caseNumber: row.case_number,
    status: row.status,
    category: {
      id: row.category_id,
      code: row.category_code,
      nameEn: row.category_name_en,
      nameUr: row.category_name_ur,
    },
    sector: { id: row.sector_id, code: row.sector_code, name: row.sector_name },
    zone: { id: row.zone_id, code: row.zone_code, name: row.zone_name },
    streetText: row.street_text,
    latitude: num(row.latitude),
    longitude: num(row.longitude),
    ackDueAt: iso(row.ack_due_at),
    slaDueAt: iso(row.sla_due_at),
    ackBreached: Boolean(row.ack_breached),
    slaBreached: Boolean(row.sla_breached),
    rejectionReason: row.rejection_reason,
    duplicateOfNumber: row.duplicate_of_number,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    resolvedAt: iso(row.resolved_at),
  };
  if (viewer.role !== 'citizen') {
    body.reporterName = row.reporter_name;
    body.reporterPhone = row.reporter_phone;
  }
  if (!detail) return body;
  body.description = row.description;
  body.sectorOverridden = Boolean(row.sector_overridden);
  return body;
}

async function caseById(db: Db, id: string): Promise<CaseRow | null> {
  const { rows } = await db.query<CaseRow>(`${CASE_SELECT} WHERE c.id = $1`, [id]);
  return rows[0] ?? null;
}

async function requireCase(db: Db, id: string, viewer: UserRecord): Promise<CaseRow> {
  const row = await caseById(db, id);
  if (!row) throw new ApiError(404, 'CASE_NOT_FOUND', 'That report does not exist.');
  assertCanView(row, viewer);
  return row;
}

async function lockCase(tx: Db, id: string): Promise<CaseRow> {
  const locked = await tx.query(`SELECT id FROM cases WHERE id = $1 FOR UPDATE`, [id]);
  if (!locked.rows[0]) throw new ApiError(404, 'CASE_NOT_FOUND', 'That report does not exist.');
  const row = await caseById(tx, id);
  if (!row) throw new ApiError(404, 'CASE_NOT_FOUND', 'That report does not exist.');
  return row;
}

export async function presentCase(db: Db, id: string, viewer: UserRecord, secret: string) {
  const row = await requireCase(db, id, viewer);
  const photos = await db.query<{ id: string; kind: string }>(
    `SELECT id, kind FROM case_photos WHERE case_id = $1 ORDER BY created_at`,
    [id],
  );
  const events = await db.query<{
    id: string;
    from_status: string | null;
    to_status: string | null;
    note: string | null;
    created_at: Date | string;
    actor_name: string | null;
    actor_role: string | null;
  }>(
    `SELECT e.id, e.from_status, e.to_status, e.note, e.created_at, u.full_name AS actor_name, u.role AS actor_role
     FROM case_events e
     LEFT JOIN users u ON u.id = e.actor_id
     WHERE e.case_id = $1
     ORDER BY e.created_at ASC, e.id ASC`,
    [id],
  );
  return {
    ...present(row, viewer, secret, true),
    photos: photos.rows.map((photo) => ({
      id: photo.id,
      kind: photo.kind,
      path: mediaPath(secret, photo.id),
    })),
    events: events.rows.map((event) => ({
      id: event.id,
      fromStatus: event.from_status,
      toStatus: event.to_status,
      note: event.note,
      at: iso(event.created_at),
      actorLabel:
        viewer.role === 'citizen' && event.actor_role && event.actor_role !== 'citizen'
          ? row.zone_name
          : (event.actor_name ?? 'CDA Clean'),
    })),
  };
}

async function attachPhoto(tx: Db, photoId: string, userId: string, kind: string, caseId: string): Promise<void> {
  const { rows } = await tx.query<{ id: string; uploaded_by: string; kind: string; case_id: string | null }>(
    `SELECT id, uploaded_by, kind, case_id FROM case_photos WHERE id = $1`,
    [photoId],
  );
  const photo = rows[0];
  if (!photo || photo.uploaded_by !== userId || photo.kind !== kind) {
    throw new ApiError(400, 'PHOTO_INVALID', 'Upload a new photo for this step.');
  }
  if (photo.case_id && photo.case_id !== caseId) {
    throw new ApiError(400, 'PHOTO_INVALID', 'That photo belongs to another report.');
  }
  await tx.query(`UPDATE case_photos SET case_id = $1 WHERE id = $2`, [caseId, photoId]);
}

async function lookupSectorId(db: Db, lat: number, lng: number): Promise<string | null> {
  const { rows } = await db.query<SectorRow>(`SELECT * FROM sectors`);
  const inside = rows.filter((sector) => {
    return lat >= num(sector.min_lat) && lat <= num(sector.max_lat) && lng >= num(sector.min_lng) && lng <= num(sector.max_lng);
  });
  const pool = inside.length ? inside : rows;
  pool.sort(
    (a, b) =>
      haversineKm(lat, lng, num(a.center_lat), num(a.center_lng)) -
      haversineKm(lat, lng, num(b.center_lat), num(b.center_lng)),
  );
  const best = pool[0];
  if (!best) return null;
  if (!inside.length && haversineKm(lat, lng, num(best.center_lat), num(best.center_lng)) > 3) return null;
  return best.id;
}

async function nextCaseNumber(tx: Db): Promise<string> {
  const year = new Date().getFullYear();
  const { rows } = await tx.query<{ last_value: number | string }>(
    `INSERT INTO case_counters (year, last_value) VALUES ($1, 1)
     ON CONFLICT (year) DO UPDATE SET last_value = case_counters.last_value + 1
     RETURNING last_value`,
    [year],
  );
  return `CDA-${year}-${String(rows[0].last_value).padStart(6, '0')}`;
}

export async function createCase(
  db: Db,
  config: AppConfig,
  user: UserRecord,
  input: {
    categoryId: string;
    sectorId: string;
    latitude: number;
    longitude: number;
    streetText: string;
    description: string;
    photoIds: string[];
  },
) {
  if (user.role !== 'citizen') throw new ApiError(403, 'FORBIDDEN', 'Only a resident can file a report.');
  if (!insideIct(input.latitude, input.longitude)) {
    throw new ApiError(400, 'OUTSIDE_ICT', 'The pin has to be inside Islamabad.');
  }
  const id = await db.transaction(async (tx) => {
    const category = await tx.query<{
      id: string;
      name_en: string;
      name_ur: string;
      ack_hours: number;
      pause_overnight: boolean;
      active: boolean;
    }>(`SELECT id, name_en, name_ur, ack_hours, pause_overnight, active FROM categories WHERE id = $1`, [
      input.categoryId,
    ]);
    const cat = category.rows[0];
    if (!cat || !cat.active) throw new ApiError(400, 'CATEGORY_INVALID', 'Choose a complaint type.');
    const sector = await tx.query<SectorRow>(`SELECT * FROM sectors WHERE id = $1`, [input.sectorId]);
    const place = sector.rows[0];
    if (!place) throw new ApiError(400, 'SECTOR_INVALID', 'Choose a sector.');
    const distance = haversineKm(input.latitude, input.longitude, num(place.center_lat), num(place.center_lng));
    const inBox =
      input.latitude >= num(place.min_lat) &&
      input.latitude <= num(place.max_lat) &&
      input.longitude >= num(place.min_lng) &&
      input.longitude <= num(place.max_lng);
    if (!inBox && distance > 3) {
      throw new ApiError(400, 'OUTSIDE_SECTOR', 'That pin is outside the selected sector.');
    }
    const guessed = await lookupSectorId(tx, input.latitude, input.longitude);
    const caseId = randomUUID();
    const caseNumber = await nextCaseNumber(tx);
    const ackDue = addWorkingHours(new Date(), Number(cat.ack_hours), Boolean(cat.pause_overnight));
    await tx.query(
      `INSERT INTO cases (
         id, case_number, reporter_id, category_id, status, sector_id, zone_id,
         street_text, description, latitude, longitude, sector_overridden, ack_due_at
       ) VALUES ($1,$2,$3,$4,'submitted',$5,$6,$7,$8,$9,$10,$11,$12)`,
      [
        caseId,
        caseNumber,
        user.id,
        cat.id,
        place.id,
        place.zone_id,
        input.streetText,
        input.description,
        input.latitude,
        input.longitude,
        guessed != null && guessed !== place.id,
        ackDue,
      ],
    );
    for (const photoId of input.photoIds) {
      await attachPhoto(tx, photoId, user.id, 'before', caseId);
    }
    await addEvent(tx, caseId, user.id, null, 'submitted', null);
    const bosses = await listSupervisors(tx, place.zone_id);
    await notifyUsers(
      tx,
      bosses,
      caseId,
      { title: 'New cleanliness report', body: `${caseNumber} · ${cat.name_en} in ${place.code}` },
      { title: 'نئی صفائی شکایت', body: `${caseNumber} · ${place.code} میں ${cat.name_ur}` },
    );
    return caseId;
  });
  return presentCase(db, id, user, config.mediaSecret);
}

export async function listMine(db: Db, config: AppConfig, user: UserRecord, status?: string) {
  const params: unknown[] = [user.id];
  let sql = `${CASE_SELECT} WHERE c.reporter_id = $1`;
  if (status) {
    params.push(status);
    sql += ` AND c.status = $${params.length}`;
  }
  sql += ` ORDER BY c.created_at DESC LIMIT 100`;
  const { rows } = await db.query<CaseRow>(sql, params);
  return rows.map((row) => present(row, user, config.mediaSecret));
}

export async function mapPins(db: Db, sectorId: string) {
  const { rows } = await db.query<{
    id: string;
    category_code: string;
    status: string;
    latitude: number | string;
    longitude: number | string;
    created_at: Date | string;
  }>(
    `SELECT c.id, cat.code AS category_code, c.status, c.latitude, c.longitude, c.created_at
     FROM cases c
     JOIN categories cat ON cat.id = c.category_id
     WHERE c.sector_id = $1
       AND c.status NOT IN ('closed', 'rejected', 'duplicate')
     ORDER BY c.created_at DESC
     LIMIT 200`,
    [sectorId],
  );
  return rows.map((row) => ({
    id: row.id,
    categoryCode: row.category_code,
    status: row.status,
    latitude: num(row.latitude),
    longitude: num(row.longitude),
    createdAt: iso(row.created_at),
  }));
}

async function officerOnCase(tx: Db, caseId: string, user: UserRecord): Promise<void> {
  const { rows } = await tx.query<{ officer_id: string }>(
    `SELECT officer_id FROM assignments WHERE case_id = $1 AND active = TRUE`,
    [caseId],
  );
  if (!rows[0] || rows[0].officer_id !== user.id) {
    throw new ApiError(403, 'CASE_NOT_ASSIGNED_TO_YOU', 'This case is assigned to another officer.');
  }
}

export async function acceptCase(db: Db, config: AppConfig, user: UserRecord, caseId: string) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    assertSupervisor(user, row.zone_id);
    assertTransition(row.status, 'accepted');
    const due = addWorkingHours(new Date(), Number(row.resolve_hours), Boolean(row.pause_overnight));
    await tx.query(`UPDATE cases SET status = 'accepted', sla_due_at = $2, updated_at = NOW() WHERE id = $1`, [
      caseId,
      due,
    ]);
    await addEvent(tx, caseId, user.id, row.status, 'accepted', null);
    await notifyUsers(
      tx,
      [{ id: row.reporter_id, language: row.reporter_language }],
      caseId,
      { title: 'Report accepted', body: `${row.case_number} is now with the zone office.` },
      { title: 'شکایت قبول ہو گئی', body: `${row.case_number} زون آفس کے پاس ہے۔` },
    );
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function rejectCase(db: Db, config: AppConfig, user: UserRecord, caseId: string, reason: string) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    assertSupervisor(user, row.zone_id);
    assertTransition(row.status, 'rejected');
    await tx.query(
      `UPDATE cases SET status = 'rejected', rejection_reason = $2, updated_at = NOW() WHERE id = $1`,
      [caseId, reason],
    );
    await addEvent(tx, caseId, user.id, row.status, 'rejected', reason);
    await notifyUsers(
      tx,
      [{ id: row.reporter_id, language: row.reporter_language }],
      caseId,
      { title: 'Report not accepted', body: `${row.case_number}: ${reason}` },
      { title: 'شکایت قبول نہیں ہوئی', body: `${row.case_number}: ${reason}` },
    );
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function duplicateCase(
  db: Db,
  config: AppConfig,
  user: UserRecord,
  caseId: string,
  originalRef: { originalCaseId?: string; originalCaseNumber?: string },
) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    assertSupervisor(user, row.zone_id);
    assertTransition(row.status, 'duplicate');
    const params: unknown[] = [];
    let where = '';
    if (originalRef.originalCaseId) {
      params.push(originalRef.originalCaseId);
      where = `c.id = $1`;
    } else if (originalRef.originalCaseNumber) {
      params.push(originalRef.originalCaseNumber.trim().toUpperCase());
      where = `UPPER(c.case_number) = $1`;
    } else {
      throw new ApiError(400, 'VALIDATION', 'Enter the original report number.');
    }
    const found = await tx.query<CaseRow>(`${CASE_SELECT} WHERE ${where}`, params);
    const original = found.rows[0];
    if (!original || original.id === row.id) {
      throw new ApiError(400, 'ORIGINAL_NOT_FOUND', 'The original report was not found.');
    }
    if (original.sector_id !== row.sector_id) {
      throw new ApiError(400, 'ORIGINAL_OTHER_SECTOR', 'The original report is in another sector.');
    }
    if (original.status === 'rejected' || original.status === 'duplicate') {
      throw new ApiError(400, 'ORIGINAL_CLOSED', 'Choose an open original report.');
    }
    await tx.query(
      `UPDATE cases SET status = 'duplicate', duplicate_of_id = $2, updated_at = NOW() WHERE id = $1`,
      [caseId, original.id],
    );
    await addEvent(tx, caseId, user.id, row.status, 'duplicate', original.case_number);
    await notifyUsers(
      tx,
      [{ id: row.reporter_id, language: row.reporter_language }],
      caseId,
      {
        title: 'Report already on file',
        body: `${row.case_number} matches ${original.case_number}.`,
      },
      {
        title: 'یہ شکایت پہلے سے موجود ہے',
        body: `${row.case_number} اور ${original.case_number} ایک ہی مسئلہ ہیں۔`,
      },
    );
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function assignCase(db: Db, config: AppConfig, user: UserRecord, caseId: string, officerId: string) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    assertSupervisor(user, row.zone_id);
    if (!['accepted', 'assigned', 'reopened', 'in_progress'].includes(row.status)) {
      throw new ApiError(409, 'INVALID_TRANSITION', 'Accept the report before assigning a crew.');
    }
    const officers = await tx.query<{ id: string; language: string; full_name: string }>(
      `SELECT id, language, full_name FROM users
       WHERE id = $1 AND role = 'field_officer' AND zone_id = $2 AND status = 'active'`,
      [officerId, row.zone_id],
    );
    const officer = officers.rows[0];
    if (!officer) throw new ApiError(400, 'OFFICER_NOT_IN_ZONE', 'Choose a field officer from this zone.');
    assertTransition(row.status, 'assigned');
    await tx.query(
      `UPDATE assignments SET active = FALSE, released_at = NOW() WHERE case_id = $1 AND active = TRUE`,
      [caseId],
    );
    await tx.query(
      `INSERT INTO assignments (id, case_id, officer_id, assigned_by, active) VALUES ($1, $2, $3, $4, TRUE)`,
      [randomUUID(), caseId, officer.id, user.id],
    );
    await tx.query(`UPDATE cases SET status = 'assigned', updated_at = NOW() WHERE id = $1`, [caseId]);
    await addEvent(tx, caseId, user.id, row.status, 'assigned', officer.full_name);
    await notifyUsers(
      tx,
      [officer, { id: row.reporter_id, language: row.reporter_language }],
      caseId,
      { title: 'Crew assigned', body: `${row.case_number} has a field team.` },
      { title: 'ٹیم مقرر ہو گئی', body: `${row.case_number} کی فیلڈ ٹیم مقرر ہو گئی ہے۔` },
    );
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function startCase(db: Db, config: AppConfig, user: UserRecord, caseId: string) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    await officerOnCase(tx, caseId, user);
    assertTransition(row.status, 'in_progress');
    await tx.query(`UPDATE cases SET status = 'in_progress', updated_at = NOW() WHERE id = $1`, [caseId]);
    await addEvent(tx, caseId, user.id, row.status, 'in_progress', null);
    await notifyUsers(
      tx,
      [{ id: row.reporter_id, language: row.reporter_language }],
      caseId,
      { title: 'Crew is on the way', body: `${row.case_number} is in progress.` },
      { title: 'ٹیم روانہ ہو گئی', body: `${row.case_number} پر کام شروع ہو گیا ہے۔` },
    );
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function noteCase(db: Db, config: AppConfig, user: UserRecord, caseId: string, note: string) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    const supervisor = user.role === 'zone_supervisor' && user.zone_id === row.zone_id;
    if (!supervisor) await officerOnCase(tx, caseId, user);
    await addEvent(tx, caseId, user.id, row.status, row.status, note);
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function resolveCase(
  db: Db,
  config: AppConfig,
  user: UserRecord,
  caseId: string,
  photoId: string,
  note: string | undefined,
) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    await officerOnCase(tx, caseId, user);
    assertTransition(row.status, 'resolved');
    await attachPhoto(tx, photoId, user.id, 'after', caseId);
    await tx.query(
      `UPDATE cases SET status = 'resolved', resolved_at = NOW(), updated_at = NOW() WHERE id = $1`,
      [caseId],
    );
    await addEvent(tx, caseId, user.id, row.status, 'resolved', note ?? null);
    await notifyUsers(
      tx,
      [{ id: row.reporter_id, language: row.reporter_language }],
      caseId,
      {
        title: 'Report resolved',
        body: `${row.case_number} was marked resolved. Confirm within 48 hours.`,
      },
      {
        title: 'شکایت حل ہو گئی',
        body: `${row.case_number} کو حل نشان زد کیا گیا ہے۔ 48 گھنٹے میں تصدیق کریں۔`,
      },
    );
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function confirmCase(db: Db, config: AppConfig, user: UserRecord, caseId: string) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    if (user.id !== row.reporter_id) throw new ApiError(403, 'FORBIDDEN', 'Only the resident who filed this can confirm it.');
    assertTransition(row.status, 'closed');
    await tx.query(`UPDATE cases SET status = 'closed', updated_at = NOW() WHERE id = $1`, [caseId]);
    await addEvent(tx, caseId, user.id, row.status, 'closed', null);
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function reopenCase(
  db: Db,
  config: AppConfig,
  user: UserRecord,
  caseId: string,
  note: string,
  photoId: string,
) {
  await db.transaction(async (tx) => {
    const row = await lockCase(tx, caseId);
    if (user.id !== row.reporter_id) throw new ApiError(403, 'FORBIDDEN', 'Only the resident who filed this can reopen it.');
    const resolvedAt = row.resolved_at ? new Date(row.resolved_at).getTime() : 0;
    if (!resolvedAt || Date.now() - resolvedAt > 48 * 60 * 60 * 1000) {
      throw new ApiError(409, 'REOPEN_WINDOW_CLOSED', 'The 48 hour confirmation window has ended.');
    }
    assertTransition(row.status, 'reopened');
    await attachPhoto(tx, photoId, user.id, 'reopen', caseId);
    await tx.query(
      `UPDATE cases SET status = 'reopened', resolved_at = NULL, updated_at = NOW() WHERE id = $1`,
      [caseId],
    );
    await addEvent(tx, caseId, user.id, 'resolved', 'reopened', note);
    const active = await tx.query<{ officer_id: string }>(
      `SELECT officer_id FROM assignments WHERE case_id = $1 AND active = TRUE`,
      [caseId],
    );
    const officer = active.rows[0]
      ? (
          await tx.query<{ id: string; language: string; status: string; role: string }>(
            `SELECT id, language, status, role FROM users WHERE id = $1`,
            [active.rows[0].officer_id],
          )
        ).rows[0]
      : null;
    const bosses = await listSupervisors(tx, row.zone_id);
    if (officer && officer.status === 'active' && officer.role === 'field_officer') {
      const due = addWorkingHours(new Date(), Number(row.resolve_hours), Boolean(row.pause_overnight));
      await tx.query(
        `UPDATE cases SET status = 'assigned', sla_due_at = $2, sla_breached = FALSE, updated_at = NOW() WHERE id = $1`,
        [caseId, due],
      );
      await addEvent(tx, caseId, user.id, 'reopened', 'assigned', null);
      await notifyUsers(
        tx,
        [officer, ...bosses],
        caseId,
        { title: 'Resident says it is still there', body: `${row.case_number}: ${note}` },
        { title: 'رہائشی کے مطابق مسئلہ باقی ہے', body: `${row.case_number}: ${note}` },
      );
    } else {
      await notifyUsers(
        tx,
        bosses,
        caseId,
        { title: 'Report needs a new crew', body: `${row.case_number} was reopened.` },
        { title: 'شکایت دوبارہ کھل گئی', body: `${row.case_number} کے لیے نئی ٹیم درکار ہے۔` },
      );
    }
  });
  return presentCase(db, caseId, user, config.mediaSecret);
}

export async function zoneCases(
  db: Db,
  config: AppConfig,
  user: UserRecord,
  bucket: string | undefined,
  q: string | undefined,
) {
  if (user.role !== 'zone_supervisor' || !user.zone_id) {
    throw new ApiError(403, 'FORBIDDEN', 'Zone inbox is for the zone supervisor.');
  }
  const params: unknown[] = [user.zone_id];
  let sql = `${CASE_SELECT} WHERE c.zone_id = $1`;
  if (bucket === 'new') sql += ` AND c.status = 'submitted'`;
  else if (bucket === 'open') sql += ` AND c.status IN ('accepted', 'assigned', 'in_progress', 'reopened')`;
  else if (bucket === 'breached') {
    sql += ` AND (c.ack_breached OR c.sla_breached) AND c.status NOT IN ('closed', 'rejected', 'duplicate')`;
  } else if (bucket === 'closed_today') sql += ` AND c.status = 'closed' AND c.updated_at >= $2`;
  if (bucket === 'closed_today') params.push(new Date(Date.now() - 24 * 60 * 60 * 1000));
  if (q?.trim()) {
    params.push(`%${q.trim()}%`);
    sql += ` AND (c.case_number ILIKE $${params.length} OR c.street_text ILIKE $${params.length})`;
  }
  sql += ` ORDER BY c.created_at DESC LIMIT 200`;
  const { rows } = await db.query<CaseRow>(sql, params);
  return rows.map((row) => present(row, user, config.mediaSecret));
}

export async function officerJobs(db: Db, config: AppConfig, user: UserRecord, lat?: number, lng?: number) {
  if (user.role !== 'field_officer') throw new ApiError(403, 'FORBIDDEN', 'The job list is for field officers.');
  const { rows } = await db.query<CaseRow>(
    `${CASE_SELECT}
     JOIN assignments a ON a.case_id = c.id AND a.active = TRUE AND a.officer_id = $1
     WHERE c.status IN ('assigned', 'in_progress', 'reopened')
     ORDER BY c.sla_breached DESC, c.sla_due_at ASC NULLS LAST, c.created_at ASC`,
    [user.id],
  );
  const items = rows.map((row) => {
    const item = present(row, user, config.mediaSecret);
    if (lat != null && lng != null) {
      item.distanceKm = Math.round(haversineKm(lat, lng, num(row.latitude), num(row.longitude)) * 10) / 10;
    }
    return item;
  });
  if (lat != null && lng != null) {
    items.sort((a, b) => {
      const breach = Number(Boolean(b.slaBreached)) - Number(Boolean(a.slaBreached));
      if (breach) return breach;
      const aDue = a.slaDueAt ? new Date(String(a.slaDueAt)).getTime() : Number.MAX_SAFE_INTEGER;
      const bDue = b.slaDueAt ? new Date(String(b.slaDueAt)).getTime() : Number.MAX_SAFE_INTEGER;
      if (aDue !== bDue) return aDue - bDue;
      return Number(a.distanceKm ?? 0) - Number(b.distanceKm ?? 0);
    });
  }
  return items;
}

export async function zoneOfficers(db: Db, user: UserRecord) {
  if (user.role !== 'zone_supervisor' || !user.zone_id) {
    throw new ApiError(403, 'FORBIDDEN', 'Only the zone supervisor can see this crew.');
  }
  const { rows } = await db.query<{ id: string; full_name: string; employee_id: string; open_jobs: number | string }>(
    `SELECT u.id, u.full_name, u.employee_id,
        (SELECT COUNT(*) FROM assignments a
         JOIN cases c ON c.id = a.case_id
         WHERE a.officer_id = u.id AND a.active = TRUE
           AND c.status IN ('assigned', 'in_progress', 'reopened')) AS open_jobs
     FROM users u
     WHERE u.role = 'field_officer' AND u.zone_id = $1 AND u.status = 'active'
     ORDER BY u.full_name`,
    [user.zone_id],
  );
  return rows.map((row) => ({
    id: row.id,
    fullName: row.full_name,
    employeeId: row.employee_id,
    openJobs: Number(row.open_jobs),
  }));
}
