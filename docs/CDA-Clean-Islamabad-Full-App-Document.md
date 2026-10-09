# CDA-Clean Islamabad
## Full Application Document

| Field | Value |
| --- | --- |
| Product name | CDA-Clean Islamabad |
| Short name | CDA Clean |
| Owner (proposed) | Capital Development Authority (CDA), Islamabad — Sanitation operations |
| Document type | Product and technical specification |
| Version | 1.0 |
| Status | Draft for build |
| Date | 8 October 2026 |
| Frontend | Flutter (Android, iOS, and a staff/admin layout on tablet) |
| Backend | Node.js (TypeScript) |
| Primary city | Islamabad Capital Territory |

This document is the single source for what the app is, who uses it, what each screen does, how the backend is shaped, and how the first release is accepted. A development team can build from this without a second requirements pass.

---

## 1. What the app is

CDA-Clean Islamabad is the public cleanliness channel for Islamabad. A resident sees a missed collection, an overflowing bin, illegal dumping, a blocked drain, or waste burning, and files it from the phone with a photo and a map pin. The sanitation office for that sector receives the case, assigns a field team, and closes it only after an after-photo. The resident sees every status change.

The same Flutter app serves three kinds of people. Citizens report and track. Field teams work a job list. CDA officers run zones, assignments, and a city cleanliness picture. The Node.js API is the only system of record.

The product promise is simple: a cleanliness complaint in Islamabad is acknowledged, owned by a named team, and closed with proof.

---

## 2. Problem

Today a resident who wants garbage lifted in a sector usually calls a helpline, messages a social account, or waits for the next round. Those channels lose the photo, the exact spot, and the follow-up. Field teams then arrive without a pin, and the resident never sees whether the heap was cleared.

CDA-Clean Islamabad replaces that gap with one case file:

- where it is (GPS + sector + street)
- what it is (category)
- what it looked like (before photo)
- who owns it (zone office and field team)
- what “done” means (after photo and resident confirmation)

---

## 3. Goals

| Goal | How we will know it worked |
| --- | --- |
| Residents can file a valid case in under two minutes | Median time from open-app to submitted case is under 2 minutes |
| Every case has an owner | 100% of accepted cases are assigned to a zone within the SLA |
| Closures have proof | A case cannot move to Resolved without an after-photo |
| Residents can see progress | Status push reaches the reporter on every transition |
| Officers can see the city | Zone dashboard shows open cases, ageing, and resolution rate by sector |

### Out of scope for version 1

- Billing, challans, or fines collection
- Hospital or hazardous-medical waste contracts
- A separate public website (the API can serve one later)
- Integration with an existing CDA ERP until that system’s API is confirmed
- Door-to-door payments or private contractor invoicing

---

## 4. Users and roles

| Role | Who | What they can do |
| --- | --- | --- |
| Citizen | Islamabad resident or visitor | Register, report, track own cases, view collection day, confirm or reopen a closure |
| Field officer | Sanitation crew lead on a beat | See assigned cases, navigate, add progress notes, upload after-photo, mark resolved |
| Zone supervisor | In-charge of a sanitation zone | See zone queue, accept or reject, assign to a field officer, reopen, view SLA breaches |
| Directorate admin | Sanitation directorate user | All zones, users, sectors, categories, schedules, reports |
| System admin | Technical owner | Roles, audit log, configuration. No need to work cases day to day |

A person has one role. Staff accounts are created by a Directorate admin. Citizens self-register with a Pakistani mobile number.

---

## 5. Operating model

Islamabad is divided, inside the app, into sanitation zones. Each zone contains sectors (for example F-6, G-10, I-8, E-11, Blue Area). Each sector contains sub-sectors and streets. A case always belongs to exactly one sector, and that sector belongs to exactly one zone.

Proposed case life:

```
Submitted → Accepted → Assigned → In progress → Resolved → Closed
                ↘ Rejected                         ↘ Reopened → Assigned
                ↘ Duplicate
```

| Status | Meaning | Who sets it |
| --- | --- | --- |
| Submitted | Citizen filed it. Waiting for the zone. | System, on create |
| Accepted | Zone agrees it is a real sanitation job | Zone supervisor |
| Rejected | Not a sanitation job, or outside ICT, or abusive | Zone supervisor, with a reason |
| Duplicate | Same issue already open nearby | Zone supervisor, with a link to the original case |
| Assigned | A field officer owns it | Zone supervisor |
| In progress | Crew is on the way or on site | Field officer |
| Resolved | Crew uploaded an after-photo | Field officer |
| Closed | Citizen confirmed, or 48 hours passed with no dispute | System, or citizen |
| Reopened | Citizen says it is not actually clear | Citizen, within 48 hours of Resolved |

### Service times (SLA)

Clock starts when the case becomes Accepted.

| Category | Acknowledge (Submitted → Accepted) | Resolve (Accepted → Resolved) |
| --- | --- | --- |
| Overflowing bin | 4 hours | 24 hours |
| Missed door-to-door collection | 4 hours | 24 hours |
| Garbage heap | 4 hours | 24 hours |
| Illegal dumping | 8 hours | 48 hours |
| Construction debris on public road | 8 hours | 72 hours |
| Dead animal | 2 hours | 12 hours |
| Blocked drain / open manhole (sanitation) | 4 hours | 24 hours |
| Waste burning | 2 hours | 12 hours |
| Dirty public toilet | 4 hours | 24 hours |
| Other | 8 hours | 48 hours |

SLA clocks pause between 10:00 pm and 6:00 am Pakistan time, except Dead animal and Waste burning, which run around the clock.

---

## 6. Feature list

### 6.1 Citizen

1. Splash, language choice (English or Urdu), and phone OTP login.
2. Home with the user’s sector, today’s collection window, and a count of open cases.
3. Report a problem: category, up to three photos, GPS pin (adjustable within 200 metres), sector, street or landmark, short note.
4. My reports, with status, SLA indicator, and a timeline.
5. Map of the user’s own open reports. Other residents’ open reports show as anonymous pins in the same sector (category and age only, no name, no phone, no exact house).
6. Collection calendar for the user’s sector (which weekdays the beat covers that street).
7. Confirm resolution or reopen with one photo and a note.
8. Push and in-app notifications.
9. Profile: name, phone, sector, preferred language. CNIC is optional and stored only to mark a verified resident.
10. Help: what CDA Clean covers, and the sanitation helpline number.

### 6.2 Field officer

1. Today’s jobs, sorted by SLA risk, then distance.
2. Job detail with before-photos, pin, citizen note, and navigation (opens the device map).
3. Status updates: start travel, arrive, add a note.
4. Resolve: required after-photo, optional note.
5. Offline queue: if the network drops on site, the status and photo wait on the phone and sync when the signal returns. The server time of sync is stored separately from the officer’s action time.

### 6.3 Zone supervisor

1. Zone inbox: Submitted, ageing, breached SLA, unassigned.
2. Accept, reject (reason required), or mark duplicate (original case id required).
3. Assign to a field officer who belongs to that zone.
4. Reassign and reopen.
5. Zone map of open cases.
6. Simple daily strip: new, resolved, still open, breached.

### 6.4 Directorate admin

1. City dashboard: open cases, median resolution time, breach rate, by zone and sector.
2. Manage zones, sectors, streets, and which zone owns which sector.
3. Manage staff accounts and reset access.
4. Manage categories and SLA hours.
5. Manage weekly collection schedules.
6. Export cases to CSV for a date range.
7. Read the audit log (who changed a case, and when).

### 6.5 Shared

- English and Urdu throughout the Flutter UI. The API stores user-facing category names in both languages.
- One design system: CDA green, high contrast, large tap targets, works in sunlight.
- Photo capture from camera first. Gallery is allowed for citizens. Field officers must use the camera for the after-photo so the closure is taken on site.

---

## 7. Main journeys

### 7.1 Citizen files a heap of garbage

1. Open the app. If the session is valid, land on Home. Otherwise enter the mobile number and the OTP.
2. Tap Report.
3. Choose Garbage heap.
4. Take a photo. The app reads GPS. The user can nudge the pin if the heap is across the street.
5. Confirm sector (pre-filled from profile, editable) and type a landmark.
6. Submit. The app shows a case number, for example `CDA-2026-004281`.
7. The zone inbox receives it. The citizen gets “Submitted”.

### 7.2 Zone assigns and the crew closes

1. Supervisor opens the inbox, checks the photo and pin, taps Accept.
2. Supervisor assigns a field officer on that beat.
3. Officer gets a push, opens the job, taps Navigate, then In progress.
4. On site, the officer takes the after-photo and taps Resolved.
5. Citizen gets a push. They tap Looks clear (Closed) or Still there (Reopened). If they do nothing for 48 hours, the case closes.

### 7.3 Citizen disputes a closure

1. From the case, tap Still there, add one photo and a sentence.
2. Status returns to Assigned on the same officer.
3. The reopen reason is visible to the supervisor.

---

## 8. Flutter application

### 8.1 Platforms and stack

| Piece | Choice |
| --- | --- |
| Framework | Flutter (stable channel), Dart 3 |
| Platforms in v1 | Android and iOS phones. Supervisors may use a tablet; the same app uses a wider layout above 600 dp |
| State | Riverpod |
| Navigation | go_router, with role-based redirects |
| HTTP | dio, with one interceptor for the access token |
| Models | dart classes plus json_serializable |
| Maps | flutter_map with OpenStreetMap tiles, or Google Maps if CDA provides a key. Pins are the app’s own data |
| Location | geolocator |
| Camera | image_picker, camera-only path for field after-photos |
| Push | firebase_messaging |
| Local store | drift (SQLite) for the field-officer offline queue and cached profile |
| Secure storage | flutter_secure_storage for refresh token |
| i18n | flutter_localizations + ARB files, `en` and `ur` |
| Font | A font with full Urdu coverage (Noto Nastaliq Urdu for Urdu, Inter or a similar UI font for English) |

The app is one binary. After login the router sends the user to the citizen shell, the officer shell, or the supervisor/admin shell.

### 8.2 Suggested Flutter tree

```
app/
  lib/
    main.dart
    app.dart
    core/
      network/
      storage/
      theme/
      l10n/
      location/
    features/
      auth/
      home/
      reports/
      map/
      schedule/
      jobs/            # field officer
      zone_inbox/      # supervisor
      admin/
      notifications/
      profile/
    shared/
      widgets/
      models/
```

Each feature folder holds `presentation/`, `application/`, and `data/`. Screens call a controller. Controllers call a repository. Repositories call the API. Widgets do not call dio directly.

### 8.3 Navigation map

Citizen

- `/splash`
- `/language`
- `/login`
- `/otp`
- `/home`
- `/report/new`
- `/report/:id`
- `/reports`
- `/map`
- `/schedule`
- `/notifications`
- `/profile`
- `/help`

Field officer

- `/jobs`
- `/jobs/:id`

Supervisor

- `/zone`
- `/zone/case/:id`
- `/zone/map`
- `/zone/team`

Admin (directorate and system admin)

- `/admin`
- `/admin/cases`
- `/admin/cases/:id`
- `/admin/zones`
- `/admin/staff`
- `/admin/schedules`
- `/admin/categories`
- `/admin/export`

### 8.4 Screen specification

**Splash.** CDA mark and the words CDA-Clean Islamabad. If a refresh token exists, try to restore the session. Otherwise go to language (first launch) or login.

**Language.** English or اردو. Saved on the device and sent as `Accept-Language` on later calls. Can be changed from Profile.

**Login.** Mobile number, Pakistan only, normalised to `+92`. Button sends OTP. Staff have a second entry, “Staff sign in”, which asks for employee id and password and then the same OTP on their registered phone.

**OTP.** Six digits, 60-second resend, five attempts, then a 15-minute lock on that number.

**Home (citizen).** Greeting, sector name, a primary Report button, three counts (open, resolved this month, collection day), and the latest case card. Pull to refresh.

**New report.**

| Step | Fields | Rules |
| --- | --- | --- |
| 1. Category | One of the ten categories | Required |
| 2. Evidence | 1 to 3 photos, GPS | At least one photo. If GPS is off, block submit and explain how to enable it |
| 3. Place | Pin, sector, street or landmark, note (500 characters) | Pin must fall inside Islamabad Capital Territory. Sector is required |
| 4. Review | Read-only summary | Submit creates the case. Show the case number |

**Case detail.** Case number, category, status chip, SLA (“due in 6 hours” or “overdue by 3 hours”), map preview, photos, timeline of status changes, and the action that the role is allowed to take.

**My reports.** Filters: Open, Resolved, Closed, All.

**Map.** Citizen sees own cases in full and other open cases in the same sector as category pins. Tapping another resident’s pin does not reveal their name or phone.

**Schedule.** Week strip for the saved sector. Each day shows “Collection” or “No collection”, plus the published window (for example 7:00 am–2:00 pm). This is information, not a booking.

**Jobs (officer).** List cards: case number, category, distance, SLA colour (green, amber under 4 hours, red when breached). Empty state: “No jobs assigned”.

**Job detail (officer).** Same case detail, plus Start, Add note, and Resolve. Resolve stays disabled until an after-photo exists.

**Zone inbox.** Tabs: New, Open, Breached, Closed today. Search by case number. Assign sheet lists officers in the zone with their open-job count.

**Admin dashboard.** Four numbers on top: open cases, breached, median hours to resolve (last 30 days), cases filed today. Below that, a bar list of zones. Tapping a zone opens its sectors.

**Staff admin.** Create officer or supervisor: name, employee id, phone, zone, role. Deactivate instead of delete, so old timelines keep the name.

**Profile.** Name, phone (read-only), sector, language, notification toggle, sign out.

### 8.5 Visual rules

- Background: off-white `#F4F7F5`. Primary: `#0B6E4F`. Danger: `#B42318`. Warning: `#B54708`.
- Status colours stay the same on every screen: submitted slate, accepted blue, assigned indigo, in progress amber, resolved green, closed neutral, rejected or duplicate red.
- Minimum body text 16 sp. Urdu line height at least 1.6.
- Every primary action is a full-width button on phones.
- Photos show a loading state and a failure retry. The app compresses uploads to a long edge of 1600 px and JPEG quality 80 before sending.

### 8.6 Offline behaviour

Citizens need a network to submit. If submit fails, the draft stays on the phone until the user retries or discards it.

Field officers can change status and attach the after-photo offline. The queue stores action time, case id, new status, note, and the local photo path. On reconnect, the app sends the queue in order. If the server rejects an item (case already reassigned), that item surfaces as “Needs attention” and is not silently dropped.

---

## 9. Node.js backend

### 9.1 Stack

| Piece | Choice |
| --- | --- |
| Runtime | Node.js 22 LTS |
| Language | TypeScript |
| HTTP | Express |
| Validation | zod on every request body, query, and param |
| Database | PostgreSQL 16 |
| Access | SQL via `pg` and a thin query layer. Migrations with node-pg-migrate |
| Cache and OTP | Redis |
| Auth | Short-lived JWT access token (15 minutes) and rotating refresh token (30 days) |
| Files | Object storage (S3-compatible). Local disk only in development |
| Push | FCM through firebase-admin |
| Jobs | A small worker process in the same repo for SLA sweeps and auto-close |
| Logs | pino, JSON to stdout |
| Config | Environment variables only. No secrets in the repo |

### 9.2 Process shape

Two processes from one codebase:

1. `api` — HTTP.
2. `worker` — every five minutes, mark SLA breaches and auto-close resolved cases older than 48 hours.

There is no business rule that lives only in Flutter. The phone displays what the API decides.

### 9.3 Suggested backend tree

```
server/
  src/
    index.ts                 # api bootstrap
    worker.ts
    config.ts
    modules/
      auth/
      users/
      cases/
      assignments/
      media/
      catalog/               # zones, sectors, categories, schedules
      notifications/
      dashboard/
      audit/
    db/
      migrations/
      pool.ts
    middleware/
      auth.ts
      error.ts
      rateLimit.ts
  package.json
  tsconfig.json
```

A module exposes routes, a service, and SQL. Routes parse input. Services hold the rules (who may change a status, SLA math). SQL files or query functions do not branch on role.

### 9.4 Request pipeline

1. Rate limit by IP on auth routes, and by user id on case creation.
2. Read `Authorization: Bearer`.
3. Load the user and reject deactivated accounts.
4. Validate the body with zod.
5. Service runs inside a database transaction when it writes a case and its timeline together.
6. Errors return one JSON shape.

```json
{
  "error": {
    "code": "CASE_NOT_ASSIGNED_TO_YOU",
    "message": "This case is assigned to another officer."
  }
}
```

HTTP status follows the code: 400 validation, 401 unauthenticated, 403 forbidden, 404 missing, 409 conflict (wrong status transition), 429 rate limit.

---

## 10. Data model

Primary keys are UUID. Case numbers are a separate human sequence, `CDA-YYYY-######`, unique.

### 10.1 Tables

**users**

| Column | Notes |
| --- | --- |
| id | UUID |
| role | citizen, field_officer, zone_supervisor, directorate_admin, system_admin |
| full_name | |
| phone_e164 | unique |
| employee_id | unique, null for citizens |
| password_hash | null for citizens (OTP only) |
| zone_id | required for officer and supervisor |
| sector_id | citizen’s home sector, optional until they set it |
| language | en or ur |
| cnic_hash | optional, store a hash, not the raw CNIC |
| status | active or disabled |
| created_at | |

**otp_challenges** live in Redis, not Postgres: phone, code hash, attempts, expiry 5 minutes.

**zones** — id, name, code, active.

**sectors** — id, zone_id, name, code (F-6, G-10), boundary geometry (polygon, PostGIS `geography`).

**streets** — id, sector_id, name, collection_days (array of weekday numbers), window_start, window_end.

**categories** — id, code, name_en, name_ur, ack_hours, resolve_hours, pause_overnight (boolean), active.

**cases**

| Column | Notes |
| --- | --- |
| id | UUID |
| case_number | unique public id |
| reporter_id | user |
| category_id | |
| status | enum in section 5 |
| sector_id | |
| zone_id | copied from the sector at creation so history stays stable if boundaries move later |
| street_text | free text landmark |
| description | |
| latitude, longitude | |
| sla_due_at | computed at Accepted |
| sla_breached | boolean, set by the worker |
| duplicate_of_id | nullable |
| rejection_reason | nullable |
| created_at, updated_at | |

**case_photos** — id, case_id, kind (`before`, `after`, `reopen`), storage_key, uploaded_by, created_at.

**case_events** — id, case_id, actor_id, from_status, to_status, note, created_at. This is the timeline. Also written for notes that do not change status.

**assignments** — id, case_id, officer_id, assigned_by, active (boolean), created_at, released_at. One active assignment per case.

**notifications** — id, user_id, case_id, title, body, read_at, created_at.

**audit_log** — id, actor_id, action, entity, entity_id, payload jsonb, created_at. Staff changes to zones, roles, and SLA settings go here. Case timeline stays in `case_events`.

**refresh_tokens** — id, user_id, token_hash, expires_at, revoked_at.

### 10.2 Rules the database helps enforce

- A case photo of kind `after` must exist before status can become `resolved`. The service checks this inside the same transaction as the status change.
- Partial unique index: one active assignment per case.
- Sector boundary is used to default the sector from the pin. The citizen may override the sector when the pin sits near a boundary; the override is stored and flagged `sector_overridden`.

---

## 11. API

Base path: `/api/v1`. JSON only. Times are ISO-8601 in UTC. The app renders Asia/Karachi.

Authentication header: `Authorization: Bearer <accessToken>`.

### 11.1 Auth

| Method | Path | Who | Purpose |
| --- | --- | --- | --- |
| POST | `/auth/otp/request` | Public | Body `{ "phone": "+923001234567" }`. Always return 202 so the API does not reveal whether the number exists |
| POST | `/auth/otp/verify` | Public | Body `{ "phone", "code", "fullName?" }`. Creates the citizen on first success. Returns access and refresh tokens |
| POST | `/auth/staff/login` | Public | Body `{ "employeeId", "password" }`, then OTP to the staff phone |
| POST | `/auth/refresh` | Public | Rotates the refresh token |
| POST | `/auth/logout` | Any | Revokes the refresh token |

Citizen verify response:

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<opaque>",
  "user": {
    "id": "0c1d...",
    "role": "citizen",
    "fullName": "Ayesha Khan",
    "language": "ur",
    "sectorId": null
  }
}
```

### 11.2 Catalog

| Method | Path | Who | Purpose |
| --- | --- | --- | --- |
| GET | `/categories` | Any signed-in | Active categories with both names and SLA hours |
| GET | `/zones` | Staff | |
| GET | `/sectors?zoneId=` | Any signed-in | |
| GET | `/sectors/lookup?lat=&lng=` | Any signed-in | Sector whose polygon contains the point |
| GET | `/streets?sectorId=` | Any signed-in | Collection days |
| POST / PATCH | `/admin/zones`, `/admin/sectors`, `/admin/categories`, `/admin/streets` | Directorate admin | CRUD |

### 11.3 Cases

| Method | Path | Who | Purpose |
| --- | --- | --- | --- |
| POST | `/cases` | Citizen | Create |
| GET | `/cases?mine=true&status=` | Citizen | Own cases |
| GET | `/cases/:id` | Reporter, or staff of that zone, or directorate | Detail + events + photo URLs |
| GET | `/cases/map?sectorId=` | Citizen | Anonymous pins in the sector |
| POST | `/cases/:id/accept` | Zone supervisor | |
| POST | `/cases/:id/reject` | Zone supervisor | Body `{ "reason" }` |
| POST | `/cases/:id/duplicate` | Zone supervisor | Body `{ "originalCaseId" }` |
| POST | `/cases/:id/assign` | Zone supervisor | Body `{ "officerId" }` |
| POST | `/cases/:id/start` | Assigned officer | In progress |
| POST | `/cases/:id/note` | Assigned officer or supervisor | |
| POST | `/cases/:id/resolve` | Assigned officer | Fails with 409 if no after-photo |
| POST | `/cases/:id/confirm` | Reporter | Closed |
| POST | `/cases/:id/reopen` | Reporter | Body `{ "note" }`, within 48 hours, requires a reopen photo |
| GET | `/zone/cases` | Supervisor | Zone queue |
| GET | `/jobs` | Field officer | Active assignments |

Create body:

```json
{
  "categoryId": "b31...",
  "sectorId": "91a...",
  "latitude": 33.6844,
  "longitude": 73.0479,
  "streetText": "Street 22, near the markaz",
  "description": "Heap in front of the empty plot for three days",
  "photoIds": ["p1"]
}
```

The client uploads photos first (section 11.4) and sends their ids.

Case detail (trimmed):

```json
{
  "id": "c9...",
  "caseNumber": "CDA-2026-004281",
  "status": "assigned",
  "category": { "code": "garbage_heap", "name": "Garbage heap" },
  "sector": { "code": "G-10", "name": "G-10" },
  "latitude": 33.6844,
  "longitude": 73.0479,
  "slaDueAt": "2026-10-09T08:00:00Z",
  "slaBreached": false,
  "photos": [
    { "id": "p1", "kind": "before", "url": "https://..." }
  ],
  "events": [
    { "toStatus": "submitted", "at": "2026-10-08T07:12:00Z" },
    { "toStatus": "accepted", "at": "2026-10-08T08:01:00Z", "actorName": "Zone office G" },
    { "toStatus": "assigned", "at": "2026-10-08T08:05:00Z" }
  ]
}
```

Citizens never receive the officer’s personal phone in this payload. They see the zone office name.

### 11.4 Media

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/media/upload-url` | Body `{ "kind": "before" }`. Returns a short-lived PUT URL and a `photoId` |
| PUT | the signed URL | Client uploads the JPEG directly to storage |
| POST | `/media/:photoId/complete` | Client confirms. API checks the object exists and size is under 5 MB |

### 11.5 Dashboard, staff, notifications

| Method | Path | Who |
| --- | --- | --- |
| GET | `/dashboard/city?from=&to=` | Directorate admin |
| GET | `/dashboard/zone/:zoneId` | Supervisor of that zone, or directorate |
| GET | `/admin/staff` | Directorate admin |
| POST | `/admin/staff` | Directorate admin |
| PATCH | `/admin/staff/:id` | Disable, move zone, reset |
| GET | `/notifications` | Current user |
| POST | `/notifications/:id/read` | Current user |
| POST | `/devices` | Body `{ "fcmToken", "platform" }` |
| GET | `/admin/cases/export?from=&to=` | Directorate admin, returns CSV |

### 11.6 Allowed status changes

| From | To | Actor |
| --- | --- | --- |
| Submitted | Accepted, Rejected, Duplicate | Supervisor of the case zone |
| Accepted | Assigned | Supervisor |
| Assigned | In progress | Assigned officer |
| Assigned | Assigned | Supervisor reassigns (new assignment row) |
| In progress | Resolved | Assigned officer, after-photo present |
| Resolved | Closed | Reporter, or worker after 48 hours |
| Resolved | Reopened | Reporter, within 48 hours, with photo |
| Reopened | Assigned | System, back to the same officer if still active, otherwise the supervisor must assign |

Any other jump returns 409 `INVALID_TRANSITION`.

---

## 12. Notifications

| Event | Who is notified |
| --- | --- |
| Case submitted | Supervisors of that zone |
| Accepted, rejected, duplicate | Reporter |
| Assigned or reassigned | Officer and reporter |
| In progress | Reporter |
| Resolved | Reporter |
| Reopened | Officer and supervisor |
| SLA breached | Supervisor and directorate admin on duty list |
| Auto-closed | Reporter |

Each event writes a row in `notifications` and sends FCM if the user has a device token. Titles and bodies exist in English and Urdu. The user’s `language` picks the copy.

Example (Urdu reporter, resolved):

- Title: `شکایت حل ہو گئی`
- Body: `CDA-2026-004281 کو بعد والی تصویر کے ساتھ حل کر دیا گیا ہے۔ 48 گھنٹے میں تصدیق کریں۔`

---

## 13. Security and privacy

- HTTPS only.
- OTP codes are hashed in Redis. Six digits, five attempts, then lockout.
- Staff passwords are hashed with argon2.
- Access tokens carry `sub`, `role`, and `zoneId`. The service still re-reads the user on sensitive writes so a disabled account cannot finish a request with an old token.
- Citizens can read only their own cases, plus anonymous map pins.
- Officers can update only cases in their active assignment.
- Supervisors can act only inside their zone.
- CNIC, if provided, is hashed. It is never returned by the API and never shown in the UI after save.
- Photo URLs are signed and expire in 15 minutes.
- Rate limits: OTP request 5 per hour per phone, case create 10 per day per citizen, login 10 per 15 minutes per IP.
- Audit log is append-only for staff administration.
- Personal data exported in CSV is limited to case number, sector, category, status, and timestamps. Phone numbers stay out of the default export.
- Account deletion for a citizen anonymises the name and phone and keeps the case for operational history.
- The app asks for location and camera with a one-line reason in the user’s language before the system prompt.

---

## 14. Non-functional requirements

| Area | Target |
| --- | --- |
| API availability | 99.5% monthly, excluding planned maintenance announced in-app |
| Read latency | p95 under 400 ms for case list and case detail on the Islamabad deployment |
| Create case | p95 under 800 ms, excluding the photo upload |
| Photo | Reject over 5 MB. Store original compressed JPEG only in v1 |
| Scale assumption for v1 | 50,000 registered citizens, 2,000 new cases a day, 200 concurrent staff |
| Backups | Postgres daily snapshot, 14-day retention. Object storage versioning on |
| Time | Store UTC, display Asia/Karachi, pause SLA overnight as defined in section 5 |
| Accessibility | Screen-reader labels on all actions, contrast meeting WCAG AA for text |
| Languages | English and Urdu complete in v1. No mixed sentence in a single string |

---

## 15. Repository layout

Two apps, one product, one git repository:

```
cda-clean-islamabad/
  app/                 # Flutter
  server/              # Node.js
  docs/
    CDA-Clean-Islamabad-Full-App-Document.md
  README.md
```

Environments: `local`, `staging`, `production`. Staging uses a separate database, a separate bucket, and test push credentials. Production sector polygons are loaded by migration or a one-off admin import (GeoJSON).

### Local run (when implementation starts)

Flutter:

```
cd app
flutter pub get
flutter run
```

API:

```
cd server
cp .env.example .env
npm install
npm run migrate
npm run dev
```

Worker, second terminal:

```
npm run worker
```

`.env.example` lists `DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `S3_*`, `FCM_SERVICE_ACCOUNT_PATH`, and `PUBLIC_BASE_URL`. Values stay empty in the example file.

---

## 16. Delivery phases

### Phase 1 — Report and close (build this first)

- Citizen OTP, report with photo and pin, my cases, timeline
- Supervisor accept, reject, duplicate, assign
- Officer job list, in progress, resolve with after-photo
- Push notifications for those events
- English and Urdu
- SLA due time and breach flag

Phase 1 is shippable to one pilot zone (suggest G-10 or any single zone CDA names).

### Phase 2 — City picture

- Sector polygons and auto sector from pin
- Collection schedule
- Anonymous sector map
- Zone and city dashboards
- CSV export
- Citizen confirm and reopen
- Officer offline queue

### Phase 3 — Wider operations

- More zones until ICT urban sectors are covered
- Weekly cleanliness score by sector (share of cases resolved inside SLA)
- Saved replies for rejection reasons
- Optional public web page that only reads the city dashboard

---

## 17. Acceptance for Phase 1

A build of Phase 1 is accepted when all of the following are true on staging:

1. A new phone number can request an OTP, verify, and land on Home in English and, after switching, in Urdu.
2. A citizen can submit a Garbage heap case with one photo and a pin inside the pilot sector, and receive a `CDA-YYYY-######` number.
3. A supervisor in another zone cannot see or accept that case.
4. The pilot supervisor can accept and assign it. The officer receives a push.
5. The officer cannot resolve before an after-photo. After the photo, resolve succeeds and the citizen receives a push.
6. A second officer cannot start the same case.
7. Reject requires a reason. Duplicate requires an open case id in the same sector.
8. The timeline on the citizen screen matches `case_events` order.
9. A deactivated officer’s token can no longer call `/jobs` or resolve.
10. OTP brute force locks after five wrong codes.

---

## 18. Analytics the API should record

From Phase 1, store enough to answer these without a third-party tracker in the citizen app:

- Cases created per day, category, and sector
- Time from Submitted to Accepted
- Time from Accepted to Resolved
- Percent breached, by category and zone
- Reopen rate
- Rejection rate and top rejection reasons

Staff dashboards read these from Postgres. The citizen app does not embed an advertising SDK.

---

## 19. Testing

| Layer | What |
| --- | --- |
| Server unit | SLA pause window, allowed transitions, role checks |
| Server integration | Create → accept → assign → resolve against Postgres, including the missing-photo 409 |
| Flutter widget | Report wizard validation, status chip colours, Urdu layout on one long screen |
| Manual pilot | Script in section 17 on a physical Android phone and one iPhone, in daylight, with location on |

---

## 20. Open points for CDA to confirm

These do not block writing the Phase 1 code. They should be decided before production:

1. The official pilot zone and the list of sectors in that zone.
2. Whether sector boundaries will be supplied as GeoJSON by CDA.
3. The public helpline number shown on Help.
4. Whether Google Maps is required, or OpenStreetMap tiles are acceptable.
5. The legal name to print on the splash screen and store listing.
6. Data retention: how many years closed cases and photos must be kept.
7. Whether CNIC verification is required for citizens or stays optional.

---

## 21. Glossary

| Term | Meaning |
| --- | --- |
| CDA | Capital Development Authority, Islamabad |
| Case | One cleanliness report |
| Zone | Sanitation office area that owns a set of sectors |
| Sector | Islamabad sector such as F-6 or G-10 |
| Beat | The streets a field crew covers |
| SLA | The allowed hours to accept and to resolve |
| After-photo | The picture the crew must take before the case can be resolved |

---

## 22. Document history

| Version | Date | Notes |
| --- | --- | --- |
| 1.0 | 8 October 2026 | First full application document: product, Flutter app, Node.js API, data model, and Phase 1 acceptance |
