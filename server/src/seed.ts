import type { Db } from './db.js';
import { hashPassword } from './passwords.js';
import { addWorkingHours } from './sla.js';

const zoneG = '11111111-1111-4111-8111-111111111101';
const zoneF = '11111111-1111-4111-8111-111111111102';
const zoneI = '11111111-1111-4111-8111-111111111103';
const zoneBlue = '11111111-1111-4111-8111-111111111104';

const sectorG10 = '22222222-2222-4222-8222-222222222201';
const ayesha = '33333333-3333-4333-8333-333333333301';
const supervisor = '33333333-3333-4333-8333-333333333302';
const officer = '33333333-3333-4333-8333-333333333303';
const admin = '33333333-3333-4333-8333-333333333304';
const garbageHeap = '44444444-4444-4444-8444-444444444403';
const demoCase = '55555555-5555-4555-8555-555555555501';

const zones = [
  [zoneG, 'Zone G', 'G'],
  [zoneF, 'Zone F', 'F'],
  [zoneI, 'Zone I', 'I'],
  [zoneBlue, 'Blue Area', 'BLUE'],
] as const;

const sectors = [
  ['22222222-2222-4222-8222-222222222211', zoneG, 'G-9', 33.693, 73.033],
  [sectorG10, zoneG, 'G-10', 33.684, 73.019],
  ['22222222-2222-4222-8222-222222222213', zoneG, 'G-11', 33.669, 73.001],
  ['22222222-2222-4222-8222-222222222221', zoneF, 'F-6', 33.729, 73.076],
  ['22222222-2222-4222-8222-222222222222', zoneF, 'F-7', 33.721, 73.055],
  ['22222222-2222-4222-8222-222222222223', zoneF, 'F-8', 33.709, 73.037],
  ['22222222-2222-4222-8222-222222222231', zoneI, 'I-8', 33.666, 73.077],
  ['22222222-2222-4222-8222-222222222232', zoneI, 'I-10', 33.64, 73.038],
  ['22222222-2222-4222-8222-222222222241', zoneBlue, 'Blue Area', 33.71, 73.058],
] as const;

const categories = [
  ['44444444-4444-4444-8444-444444444401', 'overflowing_bin', 'Overflowing bin', 'بھرا ہوا کوڑے دان', 4, 24, true],
  ['44444444-4444-4444-8444-444444444402', 'missed_collection', 'Missed door-to-door collection', 'گھر سے کوڑا نہیں اٹھا', 4, 24, true],
  [garbageHeap, 'garbage_heap', 'Garbage heap', 'کوڑے کا ڈھیر', 4, 24, true],
  ['44444444-4444-4444-8444-444444444404', 'illegal_dumping', 'Illegal dumping', 'غیر قانونی ڈمپنگ', 8, 48, true],
  ['44444444-4444-4444-8444-444444444405', 'construction_debris', 'Construction debris', 'تعمیراتی ملبہ', 8, 72, true],
  ['44444444-4444-4444-8444-444444444406', 'dead_animal', 'Dead animal', 'مردہ جانور', 2, 12, false],
  ['44444444-4444-4444-8444-444444444407', 'blocked_drain', 'Blocked drain', 'بند نالی', 4, 24, true],
  ['44444444-4444-4444-8444-444444444408', 'waste_burning', 'Waste burning', 'کوڑا جلانا', 2, 12, false],
  ['44444444-4444-4444-8444-444444444409', 'dirty_toilet', 'Dirty public toilet', 'گندا عوامی ٹوائلٹ', 4, 24, true],
  ['44444444-4444-4444-8444-444444444410', 'other', 'Other', 'دیگر', 8, 48, true],
] as const;

export async function seed(db: Db): Promise<void> {
  for (const [id, name, code] of zones) {
    await db.query(
      `INSERT INTO zones (id, name, code) VALUES ($1, $2, $3) ON CONFLICT (id) DO NOTHING`,
      [id, name, code],
    );
  }

  for (const [id, zoneId, code, lat, lng] of sectors) {
    await db.query(
      `INSERT INTO sectors (id, zone_id, name, code, min_lat, max_lat, min_lng, max_lng, center_lat, center_lng)
       VALUES ($1, $2, $3, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (id) DO NOTHING`,
      [id, zoneId, code, lat - 0.012, lat + 0.012, lng - 0.012, lng + 0.012, lat, lng],
    );
  }

  for (const [id, code, nameEn, nameUr, ack, resolve, pause] of categories) {
    await db.query(
      `INSERT INTO categories (id, code, name_en, name_ur, ack_hours, resolve_hours, pause_overnight)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (id) DO NOTHING`,
      [id, code, nameEn, nameUr, ack, resolve, pause],
    );
  }

  const streets = [
    ['66666666-6666-4666-8666-666666666601', sectorG10, 'Street 22', '1,3,5', '07:00', '14:00'],
    ['66666666-6666-4666-8666-666666666602', sectorG10, 'Street 35', '2,4,6', '07:00', '14:00'],
    ['66666666-6666-4666-8666-666666666603', '22222222-2222-4222-8222-222222222221', 'Street 12', '1,3,5', '07:00', '14:00'],
  ] as const;
  for (const [id, sectorId, name, days, start, end] of streets) {
    await db.query(
      `INSERT INTO streets (id, sector_id, name, collection_days, window_start, window_end)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (id) DO NOTHING`,
      [id, sectorId, name, days, start, end],
    );
  }

  const passwordHash = await hashPassword('Clean@123');
  const staff = [
    [supervisor, 'zone_supervisor', 'Sana Malik', '+923009990001', 'SUP-G10', zoneG],
    [officer, 'field_officer', 'Bilal Ahmed', '+923009990002', 'OFF-G10', zoneG],
    [admin, 'directorate_admin', 'Directorate Desk', '+923009990003', 'ADM-CDA', null],
  ] as const;
  for (const [id, role, name, phone, employeeId, zoneId] of staff) {
    await db.query(
      `INSERT INTO users (id, role, full_name, phone_e164, employee_id, password_hash, zone_id, language)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'en')
       ON CONFLICT (id) DO NOTHING`,
      [id, role, name, phone, employeeId, passwordHash, zoneId],
    );
  }

  await db.query(
    `INSERT INTO users (id, role, full_name, phone_e164, sector_id, language)
     VALUES ($1, 'citizen', 'Ayesha Khan', '+923001112233', $2, 'en')
     ON CONFLICT (id) DO NOTHING`,
    [ayesha, sectorG10],
  );

  const year = new Date().getFullYear();
  await db.query(
    `INSERT INTO case_counters (year, last_value) VALUES ($1, 1)
     ON CONFLICT (year) DO UPDATE SET last_value = GREATEST(case_counters.last_value, 1)`,
    [year],
  );

  const existing = await db.query(`SELECT id FROM cases WHERE id = $1`, [demoCase]);
  if (!existing.rows[0]) {
    const ackDue = addWorkingHours(new Date(), 4, true);
    await db.query(
      `INSERT INTO cases (
         id, case_number, reporter_id, category_id, status, sector_id, zone_id,
         street_text, description, latitude, longitude, ack_due_at
       ) VALUES ($1, $2, $3, $4, 'submitted', $5, $6, $7, $8, $9, $10, $11)`,
      [
        demoCase,
        `CDA-${year}-000001`,
        ayesha,
        garbageHeap,
        sectorG10,
        zoneG,
        'Street 22, near the markaz',
        'A heap has been sitting in front of the empty plot for three days.',
        33.6844,
        73.02,
        ackDue,
      ],
    );
    await db.query(
      `INSERT INTO case_events (id, case_id, actor_id, from_status, to_status, note)
       VALUES ($1, $2, $3, NULL, 'submitted', NULL)`,
      ['55555555-5555-4555-8555-555555555502', demoCase, ayesha],
    );
  }
}
