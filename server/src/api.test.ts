import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import request from 'supertest';
import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { openDatabase } from './db.js';
import { migrate } from './migrate.js';
import { seed } from './seed.js';

const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);

test('phase 1 report and close flow', async () => {
  const uploadDir = await mkdtemp(path.join(tmpdir(), 'cda-uploads-'));
  const config = loadConfig({
    isProd: false,
    devOtp: '123456',
    uploadDir,
    jwtAccessSecret: 'test-access',
    jwtRefreshSecret: 'test-refresh',
    mediaSecret: 'test-media',
  });
  const db = await openDatabase(config, { memory: true });
  await migrate(db);
  await seed(db);
  const app = createApp(db, config);

  try {
    const health = await request(app).get('/api/v1/health');
    assert.equal(health.status, 200);
    assert.equal(health.body.devOtp, true);

    const phone = '03001110001';
    const otp = await request(app).post('/api/v1/auth/otp/request').send({ phone });
    assert.equal(otp.status, 202);
    const bad = await request(app).post('/api/v1/auth/otp/verify').send({ phone, code: '000000', fullName: 'Test Resident' });
    assert.equal(bad.status, 401);
    const verified = await request(app).post('/api/v1/auth/otp/verify').send({ phone, code: '123456', fullName: 'Test Resident' });
    assert.equal(verified.status, 200, JSON.stringify(verified.body));
    const citizen = verified.body.accessToken as string;

    const categories = await request(app).get('/api/v1/categories').set(auth(citizen));
    const heap = categories.body.find((item: { code: string }) => item.code === 'garbage_heap');
    const sectors = await request(app).get('/api/v1/sectors').set(auth(citizen));
    const g10 = sectors.body.find((item: { code: string }) => item.code === 'G-10');
    const f6 = sectors.body.find((item: { code: string }) => item.code === 'F-6');

    const created = await fileCase(app, citizen, heap.id, g10.id, 'Street 22 near the park');
    assert.equal(created.status, 'submitted');
    assert.match(created.caseNumber, /^CDA-\d{4}-\d{6}$/);

    const mine = await request(app).get('/api/v1/cases').set(auth(citizen));
    assert.ok(mine.body.some((item: { id: string }) => item.id === created.id));

    const supervisorLogin = await request(app).post('/api/v1/auth/staff/login').send({ employeeId: 'SUP-G10', password: 'Clean@123' });
    assert.equal(supervisorLogin.status, 200, JSON.stringify(supervisorLogin.body));
    const supervisor = supervisorLogin.body.accessToken as string;
    const officerLogin = await request(app).post('/api/v1/auth/staff/login').send({ employeeId: 'OFF-G10', password: 'Clean@123' });
    const officer = officerLogin.body.accessToken as string;
    const officerId = officerLogin.body.user.id as string;

    const blocked = await request(app).post(`/api/v1/cases/${created.id}/accept`).set(auth(officer));
    assert.equal(blocked.status, 403);

    const accepted = await request(app).post(`/api/v1/cases/${created.id}/accept`).set(auth(supervisor));
    assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
    assert.ok(accepted.body.slaDueAt);

    const officers = await request(app).get('/api/v1/zone/officers').set(auth(supervisor));
    assert.ok(officers.body.some((item: { id: string }) => item.id === officerId));
    const assigned = await request(app)
      .post(`/api/v1/cases/${created.id}/assign`)
      .set(auth(supervisor))
      .send({ officerId });
    assert.equal(assigned.status, 200, JSON.stringify(assigned.body));

    const jobs = await request(app).get('/api/v1/jobs').set(auth(officer));
    assert.ok(jobs.body.some((item: { id: string }) => item.id === created.id));
    const started = await request(app).post(`/api/v1/cases/${created.id}/start`).set(auth(officer));
    assert.equal(started.body.status, 'in_progress');

    const missingPhoto = await request(app)
      .post(`/api/v1/cases/${created.id}/resolve`)
      .set(auth(officer))
      .send({ photoId: '99999999-9999-4999-8999-999999999999' });
    assert.equal(missingPhoto.status, 400);

    const afterId = await upload(app, officer, 'after');
    const resolved = await request(app)
      .post(`/api/v1/cases/${created.id}/resolve`)
      .set(auth(officer))
      .send({ photoId: afterId, note: 'Heap lifted' });
    assert.equal(resolved.status, 200, JSON.stringify(resolved.body));
    assert.equal(resolved.body.status, 'resolved');
    assert.ok(resolved.body.photos.some((photo: { kind: string }) => photo.kind === 'after'));

    const photo = await request(app).get(resolved.body.photos[0].path);
    assert.equal(photo.status, 200);

    const closed = await request(app).post(`/api/v1/cases/${created.id}/confirm`).set(auth(citizen));
    assert.equal(closed.body.status, 'closed');

    const rejectedCase = await fileCase(app, citizen, heap.id, g10.id, 'Street 35 corner');
    const noReason = await request(app).post(`/api/v1/cases/${rejectedCase.id}/reject`).set(auth(supervisor)).send({ reason: 'no' });
    assert.equal(noReason.status, 400);
    const rejected = await request(app)
      .post(`/api/v1/cases/${rejectedCase.id}/reject`)
      .set(auth(supervisor))
      .send({ reason: 'Private plot, not a public road.' });
    assert.equal(rejected.body.status, 'rejected');

    const original = await fileCase(app, citizen, heap.id, g10.id, 'Markaz parking');
    const copy = await fileCase(app, citizen, heap.id, g10.id, 'Markaz parking again');
    const duplicate = await request(app)
      .post(`/api/v1/cases/${copy.id}/duplicate`)
      .set(auth(supervisor))
      .send({ originalCaseNumber: original.caseNumber });
    assert.equal(duplicate.status, 200, JSON.stringify(duplicate.body));
    assert.equal(duplicate.body.status, 'duplicate');

    const otherZone = await fileCase(app, citizen, heap.id, f6.id, 'Street 12 F-6');
    const outsider = await request(app).post(`/api/v1/cases/${otherZone.id}/accept`).set(auth(supervisor));
    assert.equal(outsider.status, 403);

    const refreshed = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: verified.body.refreshToken });
    assert.equal(refreshed.status, 200);
    const me = await request(app).get('/api/v1/me').set(auth(refreshed.body.accessToken));
    assert.equal(me.body.fullName, 'Test Resident');

    const notices = await request(app).get('/api/v1/notifications').set(auth(citizen));
    assert.ok(notices.body.length >= 1);

    const adminLogin = await request(app).post('/api/v1/auth/staff/login').send({ employeeId: 'ADM-CDA', password: 'Clean@123' });
    const dashboard = await request(app).get('/api/v1/dashboard/city').set(auth(adminLogin.body.accessToken));
    assert.equal(dashboard.status, 200);
    assert.equal(typeof dashboard.body.openCases, 'number');

    const disabled = await request(app)
      .patch(`/api/v1/admin/staff/${officerId}`)
      .set(auth(adminLogin.body.accessToken))
      .send({ status: 'disabled' });
    assert.equal(disabled.status, 200);
    const officerBlocked = await request(app).get('/api/v1/jobs').set(auth(officer));
    assert.equal(officerBlocked.status, 401);
  } finally {
    await db.close();
    await rm(uploadDir, { recursive: true, force: true });
  }
});

function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function upload(app: ReturnType<typeof createApp>, token: string, kind: string) {
  const response = await request(app)
    .post('/api/v1/media')
    .set(auth(token))
    .field('kind', kind)
    .attach('file', png, { filename: 'spot.png', contentType: 'image/png' });
  assert.equal(response.status, 201, JSON.stringify(response.body));
  return response.body.id as string;
}

async function fileCase(
  app: ReturnType<typeof createApp>,
  token: string,
  categoryId: string,
  sectorId: string,
  street: string,
) {
  const sectors = await request(app).get('/api/v1/sectors').set(auth(token));
  const sector = sectors.body.find((item: { id: string }) => item.id === sectorId);
  const photoId = await upload(app, token, 'before');
  const response = await request(app).post('/api/v1/cases').set(auth(token)).send({
    categoryId,
    sectorId,
    latitude: sector.centerLat,
    longitude: sector.centerLng,
    streetText: street,
    description: 'Test heap',
    photoIds: [photoId],
  });
  assert.equal(response.status, 201, JSON.stringify(response.body));
  return response.body;
}
