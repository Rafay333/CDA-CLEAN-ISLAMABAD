# CDA SmartSWM — Supervisor Mobile API (Developer Guide)

**Product:** Capital Development Authority — Smart Solid Waste Management  
**Backend:** `https://cda-swm.asktech.com.pk:5010`  
**API prefix:** `/api/supervisor`  
**Document date:** 2026-10-10  
**Audience:** Supervisor Android / iOS app developers  

Share **this single file** with the mobile team.

---

## 1. Authentication (every call)

| Item | Value |
|------|--------|
| Header | `authkey: CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0` |
| Identity | After login, keep `cnic` and send as `supervisor_cnic` (13 digits) on later calls |

Demo supervisor:

| Field | Value |
|-------|--------|
| CNIC | `3520212345671` |
| Password | `Password@123` |

Picture paths in responses are site-relative. Full URL = base + path  
Example: `https://cda-swm.asktech.com.pk:5010` + `/uploads/evidence/mechanical-sweeping/….jpg`

---

## 2. Endpoint map

| Action | Method | Path |
|--------|--------|------|
| Activate (first time) | POST | `/api/supervisor/activate` |
| Login | POST | `/api/supervisor/login` |
| Open issues | GET | `/api/supervisor/issues/open` |
| List issues | GET | `/api/supervisor/issues` |
| Issue detail | GET | `/api/supervisor/issues/{id}` |
| Resolve issue | POST | `/api/supervisor/issues/{id}/resolve` |
| Evidence activities | GET | `/api/supervisor/evidence/activities` |
| Evidence list | GET | `/api/supervisor/evidence` |
| Evidence upload | POST | `/api/supervisor/evidence` |
| Employees | GET | `/api/supervisor/employees` |
| Attendance get | GET | `/api/supervisor/attendance` |
| Attendance save | POST | `/api/supervisor/attendance` |
| HR tile | GET | `/api/supervisor/hr-summary` |

---

## 3. Two different picture flows (do not mix)

| Purpose | Endpoint | Max photos | Storage | Effect on PED |
|---------|----------|------------|---------|----------------|
| **Resolve** complaint / observation | `POST …/issues/{id}/resolve` | **10** | `issues/{complaint\|observation}/after/` | Clears 24h SLA → avoids late-issue penalty |
| **Daily activity evidence** | `POST …/evidence` | **10** | `evidence/{activity-folder}/` | Feeds PED evidence marks (mech sweep / wash / TCP) |

If more than **10** images are sent in one request → **HTTP 422**.

---

## 4. Login / activate

### Activate
`POST /api/supervisor/activate`  
JSON: `cnic`, `password` (min 6), optional `phone`

### Login
`POST /api/supervisor/login`  
JSON: `cnic`, `password`  

Success returns `userId`, `employeeId`, `fullName`, `cnic`, `contractorId`, `contractorCode`, `contractorName`, `accountType: "Supervisor"`.

---

## 5. Issues / complaints

### Open queue
`GET /api/supervisor/issues/open?supervisor_cnic=3520212345671`

### List
`GET /api/supervisor/issues?supervisor_cnic=…&status=pending`  
`status`: `all` | `pending` | `resolved`

### Detail
`GET /api/supervisor/issues/{id}?supervisor_cnic=…`

### Resolve (multipart) — max 10 after pictures
`POST /api/supervisor/issues/{id}/resolve`

| Field | Required |
|-------|----------|
| `supervisor_cnic` | Yes |
| `notes` | Optional |
| `resolved_by_name` | Optional |
| `after` / `after_picture` / `evidence` files | Yes — jpg/jpeg/png/webp, **1–10** |

---

## 6. Daily PED pictorial evidence (important)

Supervisors upload photos of field work for the day. These write to the same **Evidence** table PED uses.

### 6.1 Activity picker

```
GET /api/supervisor/evidence/activities
Header: authkey
```

Example item:

```json
{
  "code": "mech_sweep",
  "activity": "Mechanical Sweeping",
  "ped_tag": "mech_sweep",
  "folder": "mechanical-sweeping",
  "hits_ped": true
}
```

Use this list for the dropdown (prefer `activity_code` when uploading).

| code | activity | hits_ped |
|------|----------|----------|
| `dtd` | Door to Door Waste Collection | no* |
| `containers` | Container Collection/Clearance | no* |
| `commercial` | Collection from Commercial Areas | no* |
| `sweep_res` | Manual Sweeping - Residential | no* |
| `sweep_com` | Manual Sweeping - Commercial | no* |
| `beats` | Workers Presence at Beats | no* |
| `ppe` | Workers Allied Equipment (PPE) | no* |
| `mech_sweep` | Mechanical Sweeping | **yes** |
| `mech_wash` | Mechanical Washing | **yes** |
| `tcp` | Transfer Station Management | **yes** |
| `bulk` | Bulk Waste Collection | no* |
| `desilt` | Desilting of Drains | no* |

\*Still stored for audit. Prioritize `mech_sweep`, `mech_wash`, `tcp` for PED marks.

### 6.2 List for a day

```
GET /api/supervisor/evidence?supervisor_cnic=3520212345671&date=2026-10-10
```

Omit `date` for today (`yyyy-MM-dd`).

```json
{
  "date": "2026-10-10",
  "contractor_id": 1,
  "count": 2,
  "items": [
    {
      "evidence_id": 41,
      "activity": "Mechanical Sweeping",
      "file_path": "/uploads/evidence/mechanical-sweeping/….jpg",
      "url": "/uploads/evidence/mechanical-sweeping/….jpg",
      "geo_tag": "33.6844,73.0479",
      "date_captured": "2026-10-10",
      "verified_by": "Ali Khan (3520212345671)"
    }
  ]
}
```

### 6.3 Upload — max 10 pictures

```
POST /api/supervisor/evidence
Header: authkey
Content-Type: multipart/form-data
```

| Field | Required | Notes |
|-------|----------|--------|
| `supervisor_cnic` | **Yes** | 13 digits |
| `activity` or `activity_code` | **Yes** | e.g. `mech_sweep` |
| `photo` / `evidence` files | **Yes** | **1–10** jpg/jpeg/png/webp |
| `date` or `date_captured` | No | `yyyy-MM-dd`, default today |
| `geo_tag` or `geo` | Recommended | e.g. `33.6844,73.0479` |
| `verified_by` | No | Defaults to `Name (CNIC)` |

#### cURL

```bash
curl -X POST "https://cda-swm.asktech.com.pk:5010/api/supervisor/evidence" \
  -H "authkey: CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0" \
  -F "supervisor_cnic=3520212345671" \
  -F "activity_code=mech_sweep" \
  -F "date=2026-10-10" \
  -F "geo_tag=33.6844,73.0479" \
  -F "photo=@/path/to/sweep1.jpg" \
  -F "photo=@/path/to/sweep2.jpg"
```

#### Success

```json
{
  "success": true,
  "message": "Saved 2 evidence photo(s) for 2026-10-10 (Mechanical Sweeping). Feeds PED when regenerated for that date.",
  "date": "2026-10-10",
  "activity": "Mechanical Sweeping",
  "activity_code": "mech_sweep",
  "ped_tag": "mech_sweep",
  "hits_ped": true,
  "items": [ { "evidence_id": 41, "url": "/uploads/evidence/mechanical-sweeping/….jpg" } ]
}
```

#### Errors

| HTTP | When |
|------|------|
| 401 | Bad / missing `authkey` |
| 422 | Bad CNIC, unknown activity, no image, bad date, **more than 10 pictures** |

---

## 7. How evidence hits PED

1. App uploads evidence for date **D**.
2. Ops regenerates PED for date **D**.
3. PED reads Evidence rows for that date:
   - Mechanical Sweeping / Sweeper → mech sweep flag  
   - Mechanical Washing / Washer → mech wash flag  
   - Transfer / TCP / Enclosure → TCP flag  

App: upload correct `activity_code` with clear photos same day.  
Ops: regenerate PED for that date after uploads land.

---

## 8. Attendance

### Get
`GET /api/supervisor/attendance?supervisor_cnic=…&date=2026-10-09`  
Omit `date` for today.

### Save
`POST /api/supervisor/attendance`

```json
{
  "supervisor_cnic": "3520212345671",
  "date": "2026-10-09",
  "marks": [
    { "employee_id": 2, "present": true, "check_in": "06:00", "check_out": "14:00", "beat": "G-9", "source": "Android" },
    { "employee_id": 3, "present": false }
  ]
}
```

Only `present: true` rows are stored. Response includes `hr` summary.

### Employees (roster)
`GET /api/supervisor/employees?supervisor_cnic=…`

### HR tile
`GET /api/supervisor/hr-summary?supervisor_cnic=…&date=2026-10-09`

```json
{
  "date": "2026-10-09",
  "contractor_id": 1,
  "contractor_name": "ALTASPAK",
  "active_employees": 12,
  "present_today": 10,
  "absent_today": 2,
  "attendance_percent": 83.3,
  "meets_threshold": false
}
```

---

## 9. Suggested app flow

1. Activate once → then login.
2. Dashboard: `hr-summary` + open issues + today’s evidence count.
3. Complaints: list → detail → resolve with **≤10** after photos.
4. Daily PED evidence: load activities → capture (esp. mech sweep / wash / TCP) → upload **≤10** photos.
5. Attendance: roster → mark present → save → refresh `hr-summary`.

---

## 10. Storage (for awareness)

```
D:\SmartSWM\App_Data\uploads\
  issues\complaint|observation\before|after\
  evidence\mechanical-sweeping|mechanical-washing|transfer-tcp|…
```

Public URLs stay under `/uploads/...` — no wwwroot writes.
