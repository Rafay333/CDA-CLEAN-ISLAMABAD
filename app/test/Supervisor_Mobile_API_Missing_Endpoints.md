# CDA SmartSWM — Missing supervisor APIs (gap report)

**Product:** Capital Development Authority — Smart Solid Waste Management  
**App:** CDA Clean Islamabad supervisor app (`app/`)  
**Backend tested:** `https://cda-swm.asktech.com.pk:5010`  
**Compared with:** `Supervisor_Mobile_API_Developer_Guide.md` (2026-10-10)  
**Test date:** 2026-10-11  
**Audience:** Backend team and the mobile team  

The app now calls the live routes: login (CNIC and password), issue list, resolve, evidence upload, roster attendance, employees, and the HR tile. This file is the contract for data those routes still **cannot store**.

Authentication stays the same as the developer guide: header `authkey`, and `supervisor_cnic` (13 digits) after login. Do not invent a second key.

---

## 1. Result

The 13 routes in the developer guide are live. Login, open issues, issue detail, evidence activities, today’s evidence, the employee roster, today’s attendance, and the HR tile all returned **HTTP 200** with a valid key.

The app now writes the live routes. What those routes still cannot hold is listed below.

| What the supervisor does in the app | Where it is stored | Still missing |
|--------------------------------------|--------------------|---------------|
| Login | `POST /api/supervisor/login` with CNIC and password. The phone number is returned, not used to sign in. | Forgot password |
| Profile | Name, CNIC, and mobile come from the login response | Father name, address, date of birth |
| Activity, bulk waste, transfer photos, primary-site photos | `POST /api/supervisor/evidence` (max 10 photos) | UC, vehicle, remarks, before/after as separate fields, tagging |
| Complaints | List from `GET /issues`. Resolve with `POST /issues/{id}/resolve` | Creating a complaint (`POST /issues` is **405**). No “In Processing” status. Issue 1 has no coordinates, so the map cannot pin it |
| Attendance and the log | `GET` and `POST /api/supervisor/attendance` | Face match, shift, salary |
| Home and reports | HR tile, open complaints, today’s evidence | Notifications |

A write was **not** posted for evidence, attendance, or resolve. Those three routes were called with a bad body on purpose. Each returned **422** and saved nothing. The open complaint stayed open. Today’s evidence count stayed 0. Today’s attendance stayed all absent.

---

## 2. Live test of the documented API

Header used: `authkey` from the developer guide. Identity used: demo supervisor CNIC `3520212345671`.

| Action | Method and path | HTTP | What came back |
|--------|-----------------|------|----------------|
| Site root | `GET /` | 302 | Redirect, empty body |
| Login | `POST /api/supervisor/login` | 200 | `success: true`, `userId: 5`, `employeeId: 1`, `fullName: "Ali Khan"`, `cnic`, `phone`, `contractorId: 1`, `contractorCode: "ALTASPAK"`, `contractorName: "ALTASPAK"`, `accountType: "Supervisor"` |
| Activate | `POST /api/supervisor/activate` | 400 | Route exists. The probe body was malformed, so this was **not** a real activation and no password was changed. |
| Open issues | `GET /api/supervisor/issues/open?supervisor_cnic=…` | 200 | 1 complaint |
| List all | `GET /api/supervisor/issues?supervisor_cnic=…&status=all` | 200 | Same 1 complaint |
| List pending | `GET /api/supervisor/issues?…&status=pending` | 200 | Same 1 complaint |
| List resolved | `GET /api/supervisor/issues?…&status=resolved` | 200 | `[]` |
| Issue detail | `GET /api/supervisor/issues/1?supervisor_cnic=…` | 200 | Same complaint object |
| Create issue | `POST /api/supervisor/issues` | **405** | Method not allowed. Supervisors cannot file a complaint. |
| Resolve with no photo | `POST /api/supervisor/issues/1/resolve` | 422 | `"At least one after (cleaned) picture is required."` Issue was not resolved. |
| Evidence activities | `GET /api/supervisor/evidence/activities` | 200 | 12 codes. See the mismatch below. |
| Evidence today | `GET /api/supervisor/evidence?supervisor_cnic=…` | 200 | `date: "2026-10-11"`, `count: 0`, `items: []` |
| Evidence on 2026-10-10 | `GET /api/supervisor/evidence?…&date=2026-10-10` | 200 | `count: 0` |
| Evidence with no file | `POST /api/supervisor/evidence` | 422 | `"At least one photo/evidence image is required (jpg/jpeg/png/webp)."` Nothing stored. |
| Employees | `GET /api/supervisor/employees?supervisor_cnic=…` | 200 | 6 people for contractor 1. Fields: `employee_id`, `name`, `role`, `role_label`, `cnic`, `contact`, `is_supervisor`. No shift, salary, face, or enrolled flag. |
| Attendance today | `GET /api/supervisor/attendance?supervisor_cnic=…` | 200 | 6 rows, every `present: false`. Extra fields the guide does not show: `geo_tag`, `verified_by_app`. |
| Attendance save, bad CNIC | `POST /api/supervisor/attendance` | 422 | `"supervisor_cnic is required (13 digits)."` Nothing stored. |
| HR tile | `GET /api/supervisor/hr-summary?supervisor_cnic=…` | 200 | `contractor_name: "ALTASPAK"`, `active_employees: 6`, `present_today: 0`, `absent_today: 6`, `attendance_percent: 0`, `meets_threshold: false` |
| Missing key | any call without `authkey` | 401 | `"Invalid or missing authkey."` |
| Wrong key | `GET /api/supervisor/evidence/activities` | 401 | Same message |

Paths that returned **404** (route is not implemented):

`/api/supervisor`, `/api/supervisor/zones`, `/api/supervisor/ucs`, `/api/supervisor/primary-sites`, `/api/supervisor/sites`, `/api/supervisor/locations`, `/api/supervisor/vehicles`, `/api/supervisor/vehicle-types`, `/api/supervisor/containers`, `/api/supervisor/container-types`, `/api/supervisor/tcp`, `/api/supervisor/lookups`, `/api/supervisor/catalog`, `/api/supervisor/field-records`, `/api/supervisor/notifications`, `/api/supervisor/profile`, `/api/supervisor/complaints`, `/api/supervisor/tagging`, `/api/supervisor/forgot-password`, `/api/supervisor/password/forgot`, `/swagger/index.html`.

### Live issue object (issue 1)

```json
{
  "issue_id": 1,
  "issue_type": "Complaint",
  "source": "CitizenApp",
  "activity": "Container Overflow",
  "description": "the container has not been picked up in days",
  "status": "Open",
  "portal_status": "pending",
  "date_logged": "2026-10-10",
  "date_resolved": null,
  "resolved_at": null,
  "sector": "F-8 Markaz",
  "landmark": null,
  "geo_tag": null,
  "lat": null,
  "long": null,
  "logged_by_name": "Jawad Ahsan",
  "contractor_id": 1,
  "sla_deadline": "2026-10-11T14:28:26.7657565",
  "sla_label": "24h window",
  "penalty_ped_date": "2026-10-11",
  "penalizes": false,
  "before_pictures": ["/uploads/issues/complaint/before/….jpg"],
  "after_pictures": []
}
```

The complaints map cannot plot this. `lat`, `long`, and `geo_tag` are null. The app’s own complaint never receives an `issue_id`.

### Guide mismatch on Transfer Station / TCP

The guide says `tcp` has `hits_ped: true` and feeds the PED TCP flag.

The live catalog says otherwise:

```json
{
  "code": "tcp",
  "activity": "Transfer Station Management",
  "ped_tag": "general",
  "folder": "transfer-tcp",
  "hits_ped": false
}
```

`mech_sweep` and `mech_wash` still have `hits_ped: true`. `tcp` does not. Fix the guide or the catalog before the app treats a TCP upload as a PED mark.

The other 11 codes match the guide (`dtd`, `containers`, `commercial`, `sweep_res`, `sweep_com`, `beats`, `ppe`, `mech_sweep`, `mech_wash`, `bulk`, `desilt`).

---

## 3. Screen match

Dropdown lists in the app (`WasteCatalog`) are empty: activities, zones, union councils, container types, TCP names. Primary site, location, and vehicle type dropdowns are hardcoded empty. Zone polygons exist only as local XML (`Zone-4_UCs.xml`, `Zone-5_UCs.xml`), named like `Zone 4: UC-017`.

| App screen | Fields the screen saves | Closest live route | Why it does not fit |
|------------|-------------------------|--------------------|---------------------|
| Login | Display name, email, remember-me | `POST /api/supervisor/login` | App never sends CNIC or password. Login response is not kept. |
| Forgot password | CNIC | none | Continue only validates the CNIC on the phone. |
| Profile | name, father name, CNIC, address, mobile, date of birth | login returns `fullName`, `cnic`, `phone` only | No read or update for father name, address, or date of birth. |
| Primary site | area `Rural`, UC, primary site, location, vehicle type, vehicle number, GPS, before photo, container activity, after photo, remarks | `POST /api/supervisor/evidence` | Evidence is one activity code plus up to 10 photos, one geo tag, and one date. It has no site, vehicle, before/after pair, or remarks. |
| Transfer station — vehicle trips | same site and vehicle fields as primary | evidence `tcp` | Same gap, and live `tcp` does not hit PED. |
| Transfer station — Zero Waste | TCP name, before photos, after photos | evidence `tcp` | No TCP name, no before/after. |
| Activity | activity, zone, one or more UCs, pictures per UC | evidence activity codes | No zone, no UC, no per-UC groups. App rule is **2 pictures per UC** (unlimited only if an activity is flagged). API rule is **10 pictures per request**. |
| Tagging | “Tagging of Containers” once, plus container type. No photos. | none | Evidence requires a photo and has no container type. |
| Bulk waste | unlimited general pictures, not grouped by UC | evidence `bulk` | API stops at 10 pictures and still requires an activity code. The screen is general pictorial evidence. |
| Submit complaint | description, before photos, GPS (not connected yet) | none (`POST /issues` is 405) | Citizen app can create issues. This supervisor app cannot. |
| Complaint details | status New → In Processing → Resolved, timeline, follow-up note | `POST /issues/{id}/resolve` | Resolve needs 1–10 after photos and jumps to resolved. The app’s middle status does not exist. Follow-up text has nowhere to go until resolve, and the local complaint has no id. |
| Complaints map | search text, filters All / New / In Processing / Resolved, UC polygons | `GET /issues` | Filters are `all`, `pending`, `resolved` only. No search. No polygon payload. Sample pin has no coordinates. |
| Worker management | pick employee, shift Day / Evening / Night, 3 face photos, reset face | `GET /employees` | Roster has no `shift`, `enrolled`, `salary`, `faceRegisteredAt`, or photo URL. |
| Attendance | 3 face photos, GPS accuracy, mock-GPS flag, device id. Result is check-in or check-out plus match percent. | `POST /attendance` | That route stores a roster tick (`employee_id`, `present`, `check_in`, `check_out`, `beat`, `source`). It does not match a face. |
| Attendance log | date, search by name / CNIC / employee id. Row shows In/Out, similarity, geo. | `GET /attendance` | Rows have no similarity, shift, or face photo. |
| HR summary tile | not on the home screen | `GET /hr-summary` | Live and usable. The home screen does not call it. |
| Notifications | none yet | none | Screen says alerts will appear once connected. |
| Sync | waste record and complaint | none | `markPendingSynced()` only copies timestamps in memory. Sign-out is blocked until that fake sync runs. |

---

## 4. Missing APIs

Same header on every call: `authkey`.  
Same identity on every call that is not login or activate: `supervisor_cnic`.  
Dates are `yyyy-MM-dd`. Times are `HH:mm` in Asia/Karachi.  
Picture files are `jpg`, `jpeg`, `png`, or `webp`.  
Public picture URL = `https://cda-swm.asktech.com.pk:5010` + path.  
Errors stay in the style already live: **401** bad or missing key, **422** `{ "success": false, "message": "…" }`, **404** unknown id.

Build these in the order in section 5. Field records and the catalog unblock Solid Waste. Complaint create and in-processing unblock Complaints. Face routes unblock HR. The rest are profile, password, and notifications.

### 4.1 Catalog (dropdowns and map outlines)

The app cannot save a real primary site, transfer trip, or activity until these lists exist. They are empty in code today.

#### `GET /api/supervisor/catalog?supervisor_cnic={cnic}`

One payload for every dropdown. Scope it to the supervisor’s contractor.

```json
{
  "zones": [
    { "code": "Zone-4", "name": "Zone 4" },
    { "code": "Zone-5", "name": "Zone 5" }
  ],
  "ucs": [
    { "code": "UC-017", "name": "UC-017", "zone_code": "Zone-4" }
  ],
  "activities": [
    {
      "name": "Door to Door Waste Collection",
      "code": "dtd",
      "picture_limit_per_uc": 2,
      "unlimited_pictures": false
    }
  ],
  "container_types": ["Open container", "Compactor bin"],
  "tcp_names": ["TCP G-9"],
  "vehicle_types": ["Compactor", "Dumper"],
  "primary_sites": [
    { "id": 10, "name": "Site A", "uc_code": "UC-017", "zone_code": "Zone-4" }
  ],
  "locations": [
    { "id": 20, "name": "Main road", "uc_code": "UC-017" }
  ]
}
```

Rules the app already enforces:

- Activity pictures: **2 per UC** when `unlimited_pictures` is false. Null limit means unlimited.
- Zone values the activity screen expects are `Zone-4` and `Zone-5`. UC choices change when the zone changes.
- Primary site and transfer screens are rural only (`area = "Rural"`).
- Tagging uses one fixed label, `Tagging of Containers`, plus `container_types`.
- Transfer type is `Vehicle trips` or `Zero Waste`. Zero Waste uses `tcp_names`, not the vehicle fields.

`422` when `supervisor_cnic` is missing or not 13 digits.  
`200` with empty arrays is valid when a contractor has no sites yet. Do not 404 an empty list.

#### `GET /api/supervisor/zones/{zone_code}/boundary?supervisor_cnic={cnic}`

Returns the polygons now shipped in `app/test/On_map/Zone-4_UCs.xml` and `Zone-5_UCs.xml`.

`zone_code`: `Zone-4` or `Zone-5`.

```json
{
  "zone_code": "Zone-4",
  "areas": [
    {
      "name": "Zone 4: UC-017",
      "uc_code": "UC-017",
      "margin": 0.001,
      "points": [{ "lat": 33.764518, "lng": 73.237675 }]
    }
  ]
}
```

`404` when the zone code is unknown.

---

### 4.2 Field records (Solid Waste “Save Record”)

This is the store for Primary Sites, Transfer Stations, Activity, Tagging, and Bulk Waste. Do not fold these into `POST /api/supervisor/evidence`. That route is a flat PED photo drop (max 10, one activity, one geo tag). These forms are a different record.

#### `POST /api/supervisor/field-records`

`Content-Type: multipart/form-data`  
Header: `authkey`

| Field | Required | Notes |
|-------|----------|--------|
| `supervisor_cnic` | Yes | 13 digits |
| `kind` | Yes | `primary`, `transfer`, `activity`, `tagging`, `bulk` |
| `area` | Yes for `primary` and `transfer` | App sends `Rural` |
| `date` | No | `yyyy-MM-dd`, default today |
| `latitude`, `longitude` | No | Decimal degrees. App GPS is not connected yet; accept null. |
| `remarks` | No | Primary photo step |

**`kind=primary`**

| Field | Required |
|-------|----------|
| `uc_code` | Yes |
| `primary_site_id` | Yes. Must belong to that UC in the catalog. |
| `location_id` | No |
| `vehicle_type` | No |
| `vehicle_number` | No |
| `container_activity` | Yes. One of `container_types`, or an activity name from the catalog. The screen label is “Activity”. |
| `before` files | No. Repeat the part name `before`. |
| `after` files | No. Repeat the part name `after`. |

**`kind=transfer`**

| Field | Required |
|-------|----------|
| `mode` | Yes. `vehicle_trips` or `zero_waste` |
| Vehicle mode | Same UC, site, location, vehicle type, vehicle number, and `before` as primary. No container activity. |
| `tcp_name` | Yes when `mode=zero_waste`. Must be in `tcp_names`. |
| `before`, `after` | Used for Zero Waste. Vehicle mode uses `before` on the first step; after photos can be added later with `PATCH`. |

**`kind=activity`**

| Field | Required |
|-------|----------|
| `activity` or `activity_code` | Yes. From catalog `activities`. |
| `zone_code` | Yes. `Zone-4` or `Zone-5` |
| `groups` | Yes. JSON string, one object per UC. |

```json
[
  { "uc_code": "UC-017", "photo_keys": ["g0p0", "g0p1"] },
  { "uc_code": "UC-044", "photo_keys": ["g1p0"] }
]
```

Each picture is a file part whose name equals `photo_keys` (`g0p0`, …).  
A UC may appear once. Every group needs a `uc_code` in that zone.  
If the activity is not unlimited, more than **2** pictures in one group → **422**.  
This record does **not** also write the PED Evidence table. PED stays on `POST /api/supervisor/evidence` for `mech_sweep`, `mech_wash`, and (once the catalog flag is corrected) `tcp`.

**`kind=tagging`**

| Field | Required |
|-------|----------|
| `tagging` | Yes. Value `Tagging of Containers` |
| `container_type` | Yes. One of `container_types`. |

No photos.

**`kind=bulk`**

| Field | Required |
|-------|----------|
| `photo` | Yes, at least 1. Repeat the part name. Not grouped by UC. |

Cap bulk at **30** pictures per record so a phone cannot upload without a limit. Over the cap → **422**. This is wider than the evidence cap of 10 because the screen says “as many pictures as this record needs.”

#### Success `201`

```json
{
  "success": true,
  "record_id": 501,
  "kind": "primary",
  "status": "pending",
  "date": "2026-10-11",
  "saved_at": "2026-10-11T11:40:00+05:00",
  "before": ["/uploads/field-records/501/before/….jpg"],
  "after": [],
  "groups": []
}
```

`status` starts at `pending`. The record-details screen shows that badge until a later review API exists. Do not invent a review workflow in this call.

#### Errors

| HTTP | When |
|------|------|
| 401 | Bad or missing `authkey` |
| 422 | Bad CNIC, unknown `kind`, unknown UC / site / activity / container / TCP, missing required field, too many pictures, UC not in the selected zone, duplicate UC in `groups` |
| 413 | File too large. State the byte limit in `message`. |

#### `GET /api/supervisor/field-records?supervisor_cnic={cnic}&date={yyyy-MM-dd}&kind={kind}`

`date` defaults to today. `kind` is optional.

```json
{
  "date": "2026-10-11",
  "count": 1,
  "items": [
    {
      "record_id": 501,
      "kind": "activity",
      "status": "pending",
      "activity": "Door to Door Waste Collection",
      "zone_code": "Zone-4",
      "saved_at": "2026-10-11T11:40:00+05:00",
      "groups": [
        {
          "uc_code": "UC-017",
          "photos": ["/uploads/field-records/501/groups/….jpg"]
        }
      ]
    }
  ]
}
```

The reports tab and the sync sheet need this list. A record saved here is the thing “Sync now” should upload. After a **201**, the app can treat that record as synced.

#### `GET /api/supervisor/field-records/{id}?supervisor_cnic={cnic}`

Full record for the record-details screen. Include every field that was posted, plus picture URLs. `404` when the id is not this supervisor’s contractor.

#### `PATCH /api/supervisor/field-records/{id}`

Multipart. Used when the record-details screen adds after photos (`Upload After Photo` on primary and transfer vehicle trips).

| Field | Required |
|-------|----------|
| `supervisor_cnic` | Yes |
| `after` files | At least one, unless `remarks` is sent alone |
| `remarks` | No. Replaces the previous remarks when sent. |

Do not allow `kind` to change. `404` for an unknown id. `422` when the kind is `tagging`, `activity`, or `bulk` (those screens do not add after photos this way).

#### Storage

```
uploads/field-records/{record_id}/before/
uploads/field-records/{record_id}/after/
uploads/field-records/{record_id}/groups/
uploads/field-records/{record_id}/bulk/
```

Keep these folders apart from `uploads/evidence/` and `uploads/issues/`.

---

### 4.3 Complaints the supervisor files

Live issues are `source: "CitizenApp"`. The app has **Submit Complaint** and a status the API does not have.

App status → API:

| App label | Stored `status` | Stored `portal_status` |
|-----------|-----------------|-------------------------|
| New | `Open` | `pending` |
| In Processing | `Open` | `in_processing` |
| Resolved | `Resolved` | `resolved` |

Extend list filters. `status=all|pending|in_processing|resolved`.  
`pending` stays “not resolved” (portal pending **or** in processing) so the current open queue does not change meaning.  
`GET /api/supervisor/issues/open` keeps returning unresolved rows, including `in_processing`.

Add `q` on list and open: case-insensitive match on description, sector, landmark, activity, and logged-by name. The map search box uses it.

#### `POST /api/supervisor/complaints`

Multipart. This is the missing create. `POST /api/supervisor/issues` should stay **405** so existing clients do not change.

| Field | Required | Notes |
|-------|----------|--------|
| `supervisor_cnic` | Yes | |
| `description` | Yes | The submit screen blocks an empty description. |
| `latitude`, `longitude` | No | The screen shows “Live location is not connected yet.” Store null until GPS is sent. |
| `sector` | No | |
| `landmark` | No | |
| `activity` | No | Free text, same shape as issue `activity` (`Container Overflow`). |
| `before` / `photo` files | No | 0–10. Over 10 → **422**, same cap as resolve. |

Success `201`:

```json
{
  "success": true,
  "issue_id": 88,
  "status": "Open",
  "portal_status": "pending",
  "source": "SupervisorApp",
  "date_logged": "2026-10-11",
  "sla_deadline": "2026-10-12T11:40:00+05:00",
  "sla_label": "24h window",
  "before_pictures": ["/uploads/issues/complaint/before/….jpg"],
  "after_pictures": []
}
```

The new row must appear in `GET /issues`, `GET /issues/open`, and `GET /issues/{id}` for that supervisor’s contractor. `logged_by_name` is the supervisor’s name.

`422` when description is blank, CNIC is bad, or more than 10 pictures are sent.

#### `POST /api/supervisor/issues/{id}/status`

JSON. This is the “Take Action → In Processing” step. It is not resolve.

```json
{
  "supervisor_cnic": "3520212345671",
  "portal_status": "in_processing"
}
```

Only allow `pending` → `in_processing`.  
`422` if the issue is already resolved, or if `portal_status` is anything else.  
`404` if the issue is not visible to this supervisor.

Success `200` returns the full issue object with `portal_status: "in_processing"` and `status: "Open"`. Append a timeline entry (see below).

#### Resolve stays `POST /api/supervisor/issues/{id}/resolve`

Already live. Mobile must send it only from “Mark as Resolved”, with 1–10 after pictures. Map the after-photo description to the existing `notes` field. Optional `resolved_by_name` stays as documented.

Allow resolve from both `pending` and `in_processing`.  
`422` when there is no after picture (already live) or the issue is already resolved.

#### Timeline on issue detail

Add `timeline` to `GET /api/supervisor/issues/{id}` so the activity list on complaint details is not phone-only.

```json
"timeline": [
  { "title": "Marked as New", "at": "2026-10-11T11:00:00+05:00" },
  { "title": "Marked as In Processing", "at": "2026-10-11T11:20:00+05:00" },
  { "title": "Marked as Resolved", "at": "2026-10-11T12:00:00+05:00" }
]
```

#### Map pins

Every issue that should appear on the map needs numeric `lat` and `long` (or a `geo_tag` of `lat,lng`). Issue 1 cannot be drawn until those are filled. Boundary polygons come from section 4.1, not from the issue list.

---

### 4.4 Face HR

The app’s HR module does not call `/api/supervisor/attendance`. It calls `http://localhost:4000`:

| App call today | Purpose |
|----------------|---------|
| `GET /api/v1/hr/employees` | Roster for the picker. Needs `employeeId`, `name`, `cnic`, `role`, `enrolled`, `shift`. |
| `GET /api/v1/hr/employees/{id}` | Detail card |
| `GET /api/v1/hr/employees/{id}/photo` | Registered face image |
| `POST /api/v1/hr/enroll` | 3 face photos + `shift` |
| `POST /api/v1/hr/employees/{id}/reset-face` | Clears the face so a shift can be chosen again |
| `POST /api/v1/hr/attendance` | 3 face photos + GPS. Check-in or check-out. |
| `GET /api/v1/hr/attendance?date=&q=` | Log |

Those paths are **not** on port 5010. The supervisor roster (`GET /api/supervisor/employees` and `POST /api/supervisor/attendance`) cannot replace them: it has no face, no shift, no salary, and no match score.

Put the face routes on the **same host and the same `authkey`**, under `/api/supervisor`, so the phone has one backend. Keep the existing roster `POST /api/supervisor/attendance` for a manual present/absent tick. Do not overload it with face bytes.

Employee ids in the face routes are the same `employee_id` integers the roster already returns.

#### `GET /api/supervisor/employees/{id}?supervisor_cnic={cnic}`

`404` when the employee is outside this contractor.

```json
{
  "employeeId": 2,
  "name": "Ahmed Raza",
  "role": "Driver",
  "shift": "Day",
  "cnic": "3520223456782",
  "contact": "0300-2222222",
  "salary": null,
  "status": true,
  "statusId": 1,
  "statusName": "Active",
  "contractorId": 1,
  "contractorName": "ALTASPAK",
  "contractorCode": "ALTASPAK",
  "enrolled": false,
  "faceRegisteredAt": null,
  "createdBy": null,
  "createdAt": null,
  "modifiedBy": null,
  "modifiedAt": null
}
```

`shift` is `Day`, `Evening`, `Night`, or null.  
`enrolled` is true only when a face template is stored.  
Salary may be null. The detail card already prints a fallback when it is missing.

Also add `enrolled` and `shift` onto each object in the existing `GET /api/supervisor/employees` list so the picker can show the registered pill without a second call per row.

#### `GET /api/supervisor/employees/{id}/photo?supervisor_cnic={cnic}`

Image bytes (`image/jpeg`). `404` when `enrolled` is false.  
The app caches with `?v={faceRegisteredAt}`.

#### `POST /api/supervisor/employees/{id}/enroll`

Multipart.

| Field | Required |
|-------|----------|
| `supervisor_cnic` | Yes |
| `shift` | Yes. `Day`, `Evening`, or `Night` |
| `image0`, `image1`, `image2` | Yes. Exactly 3. The app takes them 5 seconds apart. |

`409` when a face is already enrolled. Body: `{ "success": false, "message": "Face already registered." }`. The app treats HTTP 409 as “ask the user to reset and try again.”  
`422` when the shift is missing, a photo is missing, or the face cannot be detected. `message` is shown on the phone.  
Success `200`:

```json
{
  "success": true,
  "message": "Face registered.",
  "employee": { "employeeId": 2, "enrolled": true, "shift": "Day", "faceRegisteredAt": "2026-10-11T11:45:00+05:00" }
}
```

#### `POST /api/supervisor/employees/{id}/reset-face`

JSON `{ "supervisor_cnic": "…" }` or an empty body plus the query `supervisor_cnic`.  
Clears the template, `shift`, and `faceRegisteredAt`. `enrolled` becomes false.  
Success `200` returns the employee object. `404` when the id is outside the contractor.

#### `POST /api/supervisor/attendance/face`

Multipart. This is check-in / check-out, not the roster save.

| Field | Required | Notes |
|-------|----------|--------|
| `supervisor_cnic` | Yes | Who is holding the phone |
| `image0`, `image1`, `image2` | Yes | At least 3. The app refuses fewer. |
| `lat`, `lng` | Yes | Decimal |
| `acc` | Yes | Metres. The app blocks accuracy worse than 300 m before calling. Still reject `acc` &gt; 300 with 422. |
| `mock` | Yes | `true` / `false`. `true` → **422** `"Fake GPS detected."` |
| `deviceId` | Yes | Stable id from the phone |

Match the face to an enrolled employee of this contractor.

Success `200`:

```json
{
  "success": true,
  "action": "checkin",
  "message": "Checked in.",
  "matchPercent": 92,
  "shift": "Day",
  "employee": {
    "employeeId": 2,
    "name": "Ahmed Raza",
    "cnic": "3520223456782",
    "role": "Driver",
    "enrolled": true,
    "faceRegisteredAt": "2026-10-11T11:45:00+05:00"
  },
  "attendance": {
    "employeeId": 2,
    "checkIn": "11:46",
    "checkOut": null,
    "geoTag": "33.6844,73.0479",
    "date": "2026-10-11"
  }
}
```

`action` is `checkin`, `checkout`, or `complete`.

- No open row today → `checkin`. Store check-in time and geo.
- Open check-in and no check-out → `checkout`. Store check-out.
- Both already stored today → `complete`. Do not insert a third row. `message` explains that the worker is already in and out.

`422` when the face matches nobody, GPS is mocked, accuracy is over 300 m, or fewer than 3 images are sent.  
Also set the roster row (`GET /api/supervisor/attendance`) for that employee: `present: true`, `check_in`, `check_out`, `geo_tag`, `source: "Face"`, `verified_by_app: true`. Then `GET /api/supervisor/hr-summary` counts the same person. One attendance fact, two reads.

#### `GET /api/supervisor/attendance/log?supervisor_cnic={cnic}&date={yyyy-MM-dd}&q={text}`

`date` defaults to today. `q` matches name, CNIC, or employee id.

```json
[
  {
    "employeeId": 2,
    "name": "Ahmed Raza",
    "cnic": "3520223456782",
    "role": "Driver",
    "enrolled": true,
    "faceRegisteredAt": "2026-10-11T11:45:00+05:00",
    "checkIn": "11:46",
    "checkOut": null,
    "geoTag": "33.6844,73.0479",
    "similarity": 0.92,
    "shift": "Day"
  }
]
```

`similarity` is 0–1. The log shows “In” when `checkOut` is null and “Out” when it is set. Empty array when nobody was marked, not 404.

#### Face storage

```
uploads/hr/faces/{employee_id}.jpg
```

Do not put face images under `uploads/evidence/` or `uploads/issues/`.

---

### 4.5 Profile

Login already returns `fullName`, `cnic`, `phone`, and contractor. The profile screen also shows father name, address, and date of birth, which are never loaded.

#### `GET /api/supervisor/profile?supervisor_cnic={cnic}`

```json
{
  "full_name": "Ali Khan",
  "father_name": "",
  "cnic": "3520212345671",
  "address": "",
  "mobile": "03001111111",
  "dob": null,
  "contractor_name": "ALTASPAK",
  "account_type": "Supervisor"
}
```

#### `PATCH /api/supervisor/profile`

JSON. Send only the fields to change.

```json
{
  "supervisor_cnic": "3520212345671",
  "father_name": "Khan",
  "address": "G-9, Islamabad",
  "mobile": "03001111111",
  "dob": "1990-01-15"
}
```

`dob` is `yyyy-MM-dd` or null. `mobile` is digits, optional leading `0`.  
`422` for a bad date or a mobile that is not a phone number.  
Success `200` returns the same object as GET.  
Do not let this call change CNIC, contractor, or password.

---

### 4.6 Forgot password

The screen collects a CNIC and shows a local “sent” state. Nothing is sent.

#### `POST /api/supervisor/password/forgot`

JSON `{ "cnic": "3520212345671" }`. Header `authkey` still required (this is the app key, not the user’s password).

Always return **200** with `{ "success": true, "message": "If this CNIC is registered, password reset instructions have been sent." }` so the call does not reveal which CNICs exist.  
`422` only when the CNIC is not 13 digits.

How the reset is delivered (SMS to the employee `contact`, or a temporary password set by an admin) is a backend choice. The app only needs this accept call. Do not return the new password in JSON.

---

### 4.7 Notifications

The bell screen is an empty state: “Alerts will appear here once they are connected.”

#### `GET /api/supervisor/notifications?supervisor_cnic={cnic}`

```json
{
  "count": 1,
  "unread": 1,
  "items": [
    {
      "id": 15,
      "title": "Complaint SLA",
      "body": "Issue 1 is inside the 24h window.",
      "at": "2026-10-11T14:00:00+05:00",
      "read": false,
      "issue_id": 1
    }
  ]
}
```

`issue_id` is null when the alert is not about a complaint. Empty `items` is the current empty screen, with HTTP 200.

Generate a row when an open issue for this contractor is inside `sla_label` / `sla_deadline`, and when `penalizes` becomes true. That is the only event the live issue payload can support today.

#### `POST /api/supervisor/notifications/{id}/read`

JSON `{ "supervisor_cnic": "…" }`.  
`200` `{ "success": true }`. `404` when the id is not this supervisor’s.

---

## 5. Build order

1. **Catalog** — without it every solid-waste dropdown stays empty, so a field record cannot be filled.
2. **Field records** (create, list, detail, after-photo patch) — this is what “Sync now” must upload for primary, transfer, activity, tagging, and bulk.
3. **Complaint create, `in_processing`, timeline, and list filter `q`** — then submit, take action, and the map search have a server row. Resolve already exists.
4. **Face employee detail, enroll, reset, photo, face attendance, attendance log** — and reflect face check-in on the existing roster and HR tile.
5. **Profile, forgot password, notifications.**

Until those exist, wiring the app to `POST /api/supervisor/evidence` or `POST /api/supervisor/attendance` would drop UC, site, vehicle, before/after, remarks, container type, TCP name, complaint id, and the face match. Those writes were left unsent on 2026-10-11 so today’s evidence, attendance, and issue 1 stayed unchanged.

---

## 6. What the phone should call once the routes exist

| User action | Call |
|-------------|------|
| Sign in | `POST /api/supervisor/login` with CNIC and password. Keep `cnic` as `supervisor_cnic`. |
| Home HR numbers | `GET /api/supervisor/hr-summary` |
| Open the solid-waste form | `GET /api/supervisor/catalog` |
| Save primary, transfer, activity, tagging, or bulk | `POST /api/supervisor/field-records` |
| Upload after photo on a saved site | `PATCH /api/supervisor/field-records/{id}` |
| Sync / reports | `GET /api/supervisor/field-records` and `GET /api/supervisor/issues` |
| Submit complaint | `POST /api/supervisor/complaints` |
| Take action | `POST /api/supervisor/issues/{id}/status` |
| Mark resolved | `POST /api/supervisor/issues/{id}/resolve` (already live, 1–10 after photos) |
| Daily PED photo (mech sweep / wash / TCP) | `POST /api/supervisor/evidence` (already live, max 10). Separate from field records. |
| Register a face / check-in | section 4.4, not the roster `POST /attendance` |
| Manual present/absent roster | existing `POST /api/supervisor/attendance` |
