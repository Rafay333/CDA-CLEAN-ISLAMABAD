import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import type { NextFunction, Request, Response } from 'express';
import type { Express } from 'express';
import multer from 'multer';
import sql from 'mssql';
import type { AppConfig } from './config.js';
import { ApiError } from './errors.js';
import { FaceWorker, defaultModelsDir, type BurstResult } from './face-worker.js';
import {
  eyeDistance,
  identify,
  packDoubles,
  packEncoding,
  residual,
  samePerson,
  unpackDoubles,
  unpackEncoding,
} from './face-rules.js';
import { schemaHint, smartSwm } from './smartswm.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024, files: 3 },
});

const faces = new Map<number, number[][]>();
let facesLoaded = false;

// Attendance recognises a face at <= 0.45. Registration refuses a face that sits within
// this wider margin of any other employee so one person can never hold two records.
const duplicateFaceDistance = 0.55;
let worker: FaceWorker | null = null;

const employeeSql = `SELECT e.EmployeeId, e.Name, e.Role, e.Cnic, e.Contact, e.Salary, e.Status,
  e.CreatedBy, e.CreatedAt, e.ModifiedBy, e.ModifiedAt, e.StatusId, s.Name AS StatusName,
  e.ContractorId, c.Name AS ContractorName, c.Code AS ContractorCode, e.FaceRegisteredAt, e.Shift,
  CASE WHEN e.FaceImage IS NULL THEN 0 ELSE 1 END AS Enrolled
  FROM Employees e
  JOIN Statuses s ON s.StatusId = e.StatusId
  LEFT JOIN ContractorProfiles c ON c.ContractorId = e.ContractorId`;

type Employee = ReturnType<typeof employeeOf>;
type Row = Record<string, unknown>;

function iso(value: unknown): string | null {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function employeeOf(row: Row) {
  const record = row;
  return {
    employeeId: Number(record.EmployeeId),
    name: String(record.Name ?? ''),
    role: String(record.Role ?? ''),
    cnic: String(record.Cnic ?? ''),
    contact: record.Contact == null ? null : String(record.Contact),
    salary: record.Salary == null ? null : Number(record.Salary),
    status: Boolean(record.Status),
    statusId: Number(record.StatusId),
    statusName: String(record.StatusName ?? ''),
    contractorId: record.ContractorId == null ? null : Number(record.ContractorId),
    contractorName: record.ContractorName == null ? null : String(record.ContractorName),
    contractorCode: record.ContractorCode == null ? null : String(record.ContractorCode),
    createdBy: record.CreatedBy == null ? null : String(record.CreatedBy),
    createdAt: iso(record.CreatedAt),
    modifiedBy: record.ModifiedBy == null ? null : String(record.ModifiedBy),
    modifiedAt: iso(record.ModifiedAt),
    faceRegisteredAt: iso(record.FaceRegisteredAt),
    enrolled: Number(record.Enrolled) === 1,
    shift: shiftOf(record.Shift),
  };
}

function clip(value: unknown, max: number): string | null {
  const text = String(value ?? '').trim();
  if (!text) return null;
  return text.length <= max ? text : text.slice(0, max);
}

async function query(config: AppConfig, text: string, inputs: Record<string, unknown> = {}) {
  try {
    const pool = await smartSwm(config);
    const request = pool.request();
    for (const [key, value] of Object.entries(inputs)) {
      if (Buffer.isBuffer(value)) request.input(key, sql.VarBinary(sql.MAX), value);
      else request.input(key, value ?? null);
    }
    return await request.query(text);
  } catch (error) {
    schemaHint(error);
  }
}

async function employee(config: AppConfig, id: number): Promise<Employee | null> {
  await ensureSchema(config);
  const result = await query(config, `${employeeSql} WHERE e.EmployeeId = @id`, { id });
  const row = result.recordset[0];
  return row ? employeeOf(row) : null;
}

async function loadFaces(config: AppConfig) {
  if (facesLoaded) return;
  const result = await query(config, 'SELECT EmployeeId, Encoding FROM EmployeeFaces WHERE Encoding IS NOT NULL');
  faces.clear();
  for (const row of result.recordset) {
    const id = Number(row.EmployeeId);
    const encoding = row.Encoding as Buffer | null;
    if (!encoding || encoding.length < 16) continue;
    const list = faces.get(id) ?? [];
    list.push(unpackEncoding(encoding));
    faces.set(id, list);
  }
  facesLoaded = true;
}

function engine(config: AppConfig) {
  if (!worker) worker = new FaceWorker(config.faceModels || defaultModelsDir());
  return worker;
}

async function withFiles<T>(images: Buffer[], run: (paths: string[]) => Promise<T>): Promise<T> {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'cda-face-'));
  try {
    const paths: string[] = [];
    for (let i = 0; i < images.length; i++) {
      const file = path.join(dir, `${i}.jpg`);
      await writeFile(file, images[i]);
      paths.push(file);
    }
    return await run(paths);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

function imagesOf(req: Request): Buffer[] {
  const files = [...((req.files as Express.Multer.File[] | undefined) ?? [])].sort((a, b) =>
    a.fieldname.localeCompare(b.fieldname),
  );
  if (files.length < 3) throw new ApiError(400, 'PHOTOS', 'Three photos are required.');
  return files.slice(0, 3).map((file) => file.buffer);
}

async function saveCheck(config: AppConfig, employeeId: number, status: string, motion: number, blink: number, images: Buffer[], feat: number[]) {
  const padded = [images[0], images[1], images[2]].map((image) => image ?? Buffer.alloc(0));
  await query(
    config,
    `INSERT INTO CheckinPhotos (EmployeeId, Time, Status, Motion, Blink, Img1, Img2, Img3, Feat)
     VALUES (@e, SYSDATETIME(), @s, @m, @b, @i1, @i2, @i3, @f)`,
    { e: employeeId, s: status, m: motion, b: blink, i1: padded[0], i2: padded[1], i3: padded[2], f: packDoubles(feat) },
  );
}

async function liveFace(config: AppConfig, employeeId: number, burst: Extract<BurstResult, { ok: true }>, images: Buffer[]) {
  const minMotion = 0.012;
  const minBlink = 0.06;
  if (burst.motion >= minMotion || burst.blink >= minBlink) {
    await saveCheck(config, employeeId, 'ok', burst.motion, burst.blink, [images[1]], burst.feat);
    return;
  }
  const previous = await query(
    config,
    `SELECT TOP 1 Id, Feat FROM CheckinPhotos
     WHERE EmployeeId = @e AND Status = 'retry' AND Time > DATEADD(minute, -10, SYSDATETIME())
     ORDER BY Id DESC`,
    { e: employeeId },
  );
  const prev = previous.recordset[0] as { Id: number; Feat: Buffer } | undefined;
  if (!prev) {
    await saveCheck(config, employeeId, 'retry', burst.motion, burst.blink, images, burst.feat);
    throw new ApiError(409, 'FACE_RETRY', 'No movement was detected. Please try again: look at the screen and blink once.');
  }
  await query(config, `UPDATE CheckinPhotos SET Status = 'retry-used' WHERE Id = @i`, { i: prev.Id });
  const change = residual(unpackDoubles(prev.Feat), burst.feat) / Math.max(1e-6, eyeDistance(burst.feat));
  if (change >= minMotion) {
    await saveCheck(config, employeeId, 'ok', burst.motion, burst.blink, [images[1]], burst.feat);
    return;
  }
  await saveCheck(config, employeeId, 'refused', burst.motion, burst.blink, images, burst.feat);
  throw new ApiError(400, 'FACE_STILL', 'Attendance not recorded: the camera sees a still picture, not a live face.');
}

type Shift = 'Day' | 'Evening' | 'Night';

function shiftOf(value: unknown): Shift | null {
  const text = String(value ?? '').trim().toLowerCase();
  if (text === 'day') return 'Day';
  if (text === 'evening') return 'Evening';
  if (text === 'night') return 'Night';
  return null;
}

// The attendance date for a punch. A Night shift that is still running after midnight
// belongs to the day it started, so a morning Night punch counts for yesterday.
const workDateSql = `CAST(CASE WHEN @night = 1 AND DATEPART(hour, SYSDATETIME()) < 12
  THEN DATEADD(day, -1, SYSDATETIME()) ELSE SYSDATETIME() END AS date)`;

let schemaChecked = false;
async function ensureSchema(config: AppConfig) {
  if (schemaChecked) return;
  await query(config, `IF COL_LENGTH('dbo.Attendances', 'Shift') IS NULL ALTER TABLE dbo.Attendances ADD Shift NVARCHAR(10) NULL`);
  await query(config, `IF COL_LENGTH('dbo.Employees', 'Shift') IS NULL ALTER TABLE dbo.Employees ADD Shift NVARCHAR(20) NULL`);
  schemaChecked = true;
}

async function today(config: AppConfig, employeeId: number, shift: Shift = 'Day') {
  await ensureSchema(config);
  const result = await query(
    config,
    `SELECT TOP 1 AttendanceId,
        CONVERT(varchar(10), [Date], 23) AS WorkDate,
        CONVERT(varchar(8), CheckIn, 108) AS CheckIn,
        CONVERT(varchar(8), CheckOut, 108) AS CheckOut,
        VerifiedByApp, Source, GeoTag, Beat, DeviceId, Similarity, Shift
     FROM Attendances
     WHERE EmployeeId = @e AND [Date] = ${workDateSql}
     ORDER BY AttendanceId DESC`,
    { e: employeeId, night: shift === 'Night' ? 1 : 0 },
  );
  const row = result.recordset[0] as Record<string, unknown> | undefined;
  if (!row) return null;
  return {
    attendanceId: Number(row.AttendanceId),
    date: row.WorkDate == null ? null : String(row.WorkDate),
    checkIn: row.CheckIn == null ? null : String(row.CheckIn),
    checkOut: row.CheckOut == null ? null : String(row.CheckOut),
    verifiedByApp: Boolean(row.VerifiedByApp),
    source: row.Source == null ? null : String(row.Source),
    geoTag: row.GeoTag == null ? null : String(row.GeoTag),
    beat: row.Beat == null ? null : String(row.Beat),
    deviceId: row.DeviceId == null ? null : String(row.DeviceId),
    similarity: row.Similarity == null ? null : Number(row.Similarity),
    shift: row.Shift == null ? 'Day' : String(row.Shift),
  };
}

function guard(handler: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res).catch((error: unknown) => {
      try {
        schemaHint(error);
      } catch (hint) {
        next(hint);
      }
    });
  };
}

export function mountHrAttendance(app: Express, config: AppConfig) {
  app.get('/api/v1/hr/employees', guard(async (_req, res) => {
    await ensureSchema(config);
    const result = await query(config, `${employeeSql} WHERE e.StatusId = 1 AND e.Status = 1 ORDER BY e.Name, e.EmployeeId`);
    res.json(result.recordset.map((row) => employeeOf(row)));
  }));

  app.get('/api/v1/hr/employees/:id', guard(async (req, res) => {
    const person = await employee(config, Number(req.params.id));
    if (!person) throw new ApiError(404, 'EMPLOYEE', 'Unknown employee.');
    res.json({ employee: person, attendance: await today(config, person.employeeId, person.shift ?? 'Day') });
  }));

  app.get('/api/v1/hr/employees/:id/photo', guard(async (req, res) => {
    const result = await query(config, 'SELECT FaceImage FROM Employees WHERE EmployeeId = @id', { id: Number(req.params.id) });
    const image = result.recordset[0]?.FaceImage as Buffer | null | undefined;
    if (!image || image.length === 0) {
      res.status(404).json({ error: { code: 'PHOTO', message: 'No face photo is saved.' } });
      return;
    }
    res.type('image/jpeg').send(image);
  }));

  app.post('/api/v1/hr/employees/:id/reset-face', guard(async (req, res) => {
    const id = Number(req.params.id);
    await query(config, 'DELETE FROM EmployeeFaces WHERE EmployeeId = @id; UPDATE Employees SET FaceImage = NULL, FaceRegisteredAt = NULL WHERE EmployeeId = @id', { id });
    faces.delete(id);
    const person = await employee(config, id);
    if (!person) throw new ApiError(404, 'EMPLOYEE', 'Unknown employee.');
    res.json(person);
  }));

  app.post('/api/v1/hr/enroll', upload.any(), guard(async (req, res) => {
    const employeeId = Number(req.body.employeeId);
    if (!Number.isInteger(employeeId)) throw new ApiError(400, 'EMPLOYEE', 'Select an employee.');
    const person = await employee(config, employeeId);
    if (!person) throw new ApiError(404, 'EMPLOYEE', 'Unknown employee.');
    if (!(person.statusId === 1 && person.status)) throw new ApiError(400, 'EMPLOYEE', 'Employee is not active.');
    if (person.enrolled) throw new ApiError(400, 'ENROLLED', 'Already registered. Reset the face before registering again.');
    const shift = shiftOf(req.body.shift);
    if (!shift) throw new ApiError(400, 'SHIFT', 'Select Day, Evening, or Night.');
    await loadFaces(config);
    const images = imagesOf(req);
    const encodings: number[][] = [];
    await withFiles(images, async (paths) => {
      for (let i = 0; i < paths.length; i++) {
        const encoded = await engine(config).encode(paths[i]);
        if (encoded.count !== 1 || !encoded.encoding) {
          throw new ApiError(400, 'FACE', `Photo ${i + 1}: exactly one clear face is needed. Try again in good light.`);
        }
        encodings.push(encoded.encoding);
      }
    });
    if (!samePerson(encodings)) throw new ApiError(400, 'FACE', 'The three photos do not look like the same person. Try again.');
    const duplicate = identify(faces, encodings, employeeId);
    if (duplicate.id >= 0 && duplicate.best <= duplicateFaceDistance) {
      const other = await employee(config, duplicate.id);
      const who = other ? `${other.name} (${other.cnic})` : String(duplicate.id);
      throw new ApiError(409, 'FACE_DUPLICATE', `This face is already registered under ${who}. One person cannot be registered twice.`);
    }
    const pool = await smartSwm(config);
    const tx = new sql.Transaction(pool);
    await tx.begin();
    try {
      await new sql.Request(tx).input('id', sql.Int, employeeId).query('DELETE FROM EmployeeFaces WHERE EmployeeId = @id');
      for (let i = 0; i < images.length; i++) {
        await new sql.Request(tx)
          .input('id', sql.Int, employeeId)
          .input('img', sql.VarBinary(sql.MAX), images[i])
          .input('enc', sql.VarBinary(1024), packEncoding(encodings[i]))
          .query('INSERT INTO EmployeeFaces (EmployeeId, Image, Encoding, Created) VALUES (@id, @img, @enc, SYSDATETIME())');
      }
      await new sql.Request(tx)
        .input('id', sql.Int, employeeId)
        .input('img', sql.VarBinary(sql.MAX), images[0])
        .input('shift', sql.NVarChar(20), shift)
        .query('UPDATE Employees SET FaceImage = @img, FaceRegisteredAt = SYSDATETIME(), Shift = @shift WHERE EmployeeId = @id');
      await tx.commit();
    } catch (error) {
      await tx.rollback();
      throw error;
    }
    faces.set(employeeId, encodings);
    const saved = await employee(config, employeeId);
    res.json({ message: 'Face registered', employee: saved });
  }));

  app.post('/api/v1/hr/attendance', upload.any(), guard(async (req, res) => {
    const lat = Number(req.body.lat);
    const lng = Number(req.body.lng);
    const accuracy = Number(req.body.acc);
    if (String(req.body.mock) === 'true') {
      throw new ApiError(400, 'GPS', 'Fake GPS detected. Turn off any fake-location app and try again.');
    }
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) throw new ApiError(400, 'GPS', 'Location permission needed.');
    if (!Number.isFinite(accuracy) || accuracy > 300) {
      throw new ApiError(400, 'GPS', `GPS signal is too weak (accuracy ${Math.round(accuracy || 0)} m). Move to an open area and try again.`);
    }
    await loadFaces(config);
    const images = imagesOf(req);
    const burst = await withFiles(images, (paths) => engine(config).burst(paths));
    if (!burst.ok) throw new ApiError(400, 'FACE', burst.error);
    const match = identify(faces, burst.encodings);
    if (match.id < 0 || match.best > 0.45) throw new ApiError(400, 'FACE', 'Face not recognised. Register this person first.');
    if (match.second - match.best < 0.08) {
      throw new ApiError(400, 'FACE', 'Not sure who this is. Try again in good light, looking straight at the camera.');
    }
    const person = await employee(config, match.id);
    if (!person || !person.enrolled) throw new ApiError(400, 'FACE', 'Face not recognised. Register this person first.');
    if (!(person.statusId === 1 && person.status)) throw new ApiError(400, 'EMPLOYEE', `${person.name} is not active.`);
    await liveFace(config, person.employeeId, burst, images);
    const geo = clip(`${lat.toFixed(5)},${lng.toFixed(5)}`, 100);
    const recent = await query(
      config,
      `SELECT TOP 2 GeoTag FROM Attendances WHERE EmployeeId = @e AND GeoTag IS NOT NULL ORDER BY AttendanceId DESC`,
      { e: person.employeeId },
    );
    if (recent.recordset.length === 2 && recent.recordset.every((row) => String(row.GeoTag) === geo)) {
      throw new ApiError(400, 'GPS', 'Attendance was not recorded: the same exact GPS position was reported 3 times in a row.');
    }
    const shift = person.shift;
    if (!shift) {
      throw new ApiError(400, 'SHIFT', 'No shift is saved for this employee. Register the face again and choose Day, Evening, or Night.');
    }
    const open = await today(config, person.employeeId, shift);
    let action: 'checkin' | 'checkout' | 'complete';
    if (!open) action = 'checkin';
    else if (!open.checkOut) action = 'checkout';
    else action = 'complete';

    // Preview match only — attendance is written when confirm=true.
    const confirmed = String(req.body.confirm ?? '').toLowerCase() === 'true';
    if (!confirmed && action !== 'complete') {
      const label = shift === 'Day' ? '' : ` (${shift} shift)`;
      const message = action === 'checkin'
        ? `Confirm check-in for ${person.name}${label}?`
        : `Confirm check-out for ${person.name}${label}?`;
      res.json({
        success: true,
        requiresConfirm: true,
        confirmed: false,
        action,
        shift,
        message,
        matchPercent: Math.round((1 - match.best) * 100),
        employee: person,
        attendance: open,
      });
      return;
    }

    if (action === 'checkin') {
      await query(
        config,
        `INSERT INTO Attendances (EmployeeId, [Date], CheckIn, VerifiedByApp, Source, GeoTag, DeviceId, CreatedBy, CreatedAt, StatusId, Similarity, Shift)
         VALUES (@e, ${workDateSql}, CAST(SYSDATETIME() AS time), 1, @src, @geo, @dev, @by, SYSUTCDATETIME(), 1, @sim, @shift)`,
        {
          e: person.employeeId,
          night: shift === 'Night' ? 1 : 0,
          src: 'Android',
          geo,
          dev: clip(req.body.deviceId, 80),
          by: clip(person.name, 100),
          sim: 1 - match.best,
          shift,
        },
      );
    } else if (action === 'checkout') {
      await query(
        config,
        `UPDATE Attendances SET CheckOut = CAST(SYSDATETIME() AS time), ModifiedBy = @by, ModifiedAt = SYSUTCDATETIME()
         WHERE AttendanceId = @id AND CheckOut IS NULL`,
        { id: open!.attendanceId, by: clip(person.name, 100) },
      );
    }
    const attendance = await today(config, person.employeeId, shift);
    const label = shift === 'Day' ? '' : ` (${shift} shift)`;
    const message = action === 'checkin'
      ? `Checked in ${person.name}${label}.`
      : action === 'checkout'
        ? `Checked out ${person.name}${label}.`
        : `${person.name} is already checked in and out for this ${shift.toLowerCase()} shift.`;
    res.json({
      success: true,
      requiresConfirm: false,
      confirmed: true,
      action,
      shift,
      message,
      matchPercent: Math.round((1 - match.best) * 100),
      employee: person,
      attendance,
    });
  }));

  app.get('/api/v1/hr/attendance', guard(async (req, res) => {
    const day = String(req.query.date ?? '');
    const q = String(req.query.q ?? '').trim();
    await ensureSchema(config);
    const result = await query(
      config,
      `SELECT a.AttendanceId, a.EmployeeId, e.Name, e.Cnic, e.Role, e.Contact,
          CONVERT(varchar(10), a.[Date], 23) AS WorkDate,
          CONVERT(varchar(8), a.CheckIn, 108) AS CheckIn,
          CONVERT(varchar(8), a.CheckOut, 108) AS CheckOut,
          a.Source, a.GeoTag, a.Similarity, a.VerifiedByApp, a.Shift, e.FaceRegisteredAt,
          CASE WHEN e.FaceImage IS NULL THEN 0 ELSE 1 END AS Enrolled
       FROM Attendances a
       JOIN Employees e ON e.EmployeeId = a.EmployeeId
       WHERE a.[Date] = COALESCE(TRY_CONVERT(date, NULLIF(@day, '')), CAST(SYSDATETIME() AS date))
         AND (@q = '' OR e.Name LIKE @like OR e.Cnic LIKE @like)
       ORDER BY a.AttendanceId DESC`,
      { day, q, like: `%${q}%` },
    );
    res.json(result.recordset.map((row) => ({
      attendanceId: Number(row.AttendanceId),
      employeeId: Number(row.EmployeeId),
      name: String(row.Name ?? ''),
      cnic: String(row.Cnic ?? ''),
      role: String(row.Role ?? ''),
      contact: row.Contact == null ? null : String(row.Contact),
      date: row.WorkDate == null ? null : String(row.WorkDate),
      checkIn: row.CheckIn == null ? null : String(row.CheckIn),
      checkOut: row.CheckOut == null ? null : String(row.CheckOut),
      source: row.Source == null ? null : String(row.Source),
      geoTag: row.GeoTag == null ? null : String(row.GeoTag),
      similarity: row.Similarity == null ? null : Number(row.Similarity),
      verifiedByApp: Boolean(row.VerifiedByApp),
      faceRegisteredAt: iso(row.FaceRegisteredAt),
      enrolled: Number(row.Enrolled) === 1,
      shift: row.Shift == null ? 'Day' : String(row.Shift),
    })));
  }));
}
