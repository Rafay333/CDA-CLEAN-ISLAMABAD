# CDA SmartSWM — Supervisor Activity Field Record API

**Audience:** Flutter Activity screen (Solid Waste → Activity)  
**Backend:** `https://cda-swm.asktech.com.pk:5010`  
**API prefix:** `/api/supervisor`  
**Document date:** 2026-10-28  
**Status:** Implemented  

Auth on every call:

| Item | Value |
|------|--------|
| Header | `authkey: CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0` |
| Identity | `supervisor_cnic` (13 digits, Supervisor-type employee) |

This is **not** `POST /api/supervisor/evidence`. Activity is a rich **field record** (before/after + GPS + remarks). Evidence remains the flat PED pictorial drop.

---

## Three Activity flows (app + API)

| Activity | Location | Container / vehicle | Photos |
|----------|----------|---------------------|--------|
| **Container Collection/Clearance** (`containers`) | `zone_code` | **Required** | **1–2 before + 1–2 after** |
| **Transfer Station Management** (`tcp`) | `zone_code` + optional `uc_code` | **Omit** | **1–2 before + 1–2 after** |
| **Bulk Waste Collection** (`bulk`) | `zone_code` + optional `uc_code` | **Omit** | **1–2 before + 1–2 after** |
| **All remaining activities** (e.g. `dtd`, sweeping, …) | `zone_code` + optional `uc_code` | **Omit** | **1–2 photos only** (send as `before`; **do not require `after`**) |

Shared: GPS (`latitude`/`longitude`), remarks (optional), one folder per record.

---

## PED decision (B)

Activity submit **also** upserts one `Evidence` row for the same `activity` name + `date` using the **first after** photo path when after files exist; for photos-only activities use the **first `before`** photo, so regenerating PED scores the Digital Pictorial Evidence subfactor (15%) without a second mobile upload.

Field-record metadata remains the source of truth for portal ops review.

---

## Lookups

### Catalog (extended)

```
GET /api/supervisor/catalog?supervisor_cnic={cnic}
```

Adds `vehicles[]` (with `vehicle_type`), zones/UCs, and sets `container_types` to inventory sizes:

- `1.1 m3`
- `8 m3`

(`tagging_container_types` is the same 1.1 m3 / 8 m3 list.)

### Vehicles (container flow only)

```
GET /api/supervisor/vehicles?supervisor_cnic={cnic}&zone_code=Zone-4
```

`zone_code` optional (accepted; fleet is contractor-scoped). Each item includes `vehicle_number` + `vehicle_type`.

### Containers by zone (container flow only)

```
GET /api/supervisor/containers?supervisor_cnic={cnic}&zone_code=Zone-4
```

Each item includes `container_name` + **`container_type`** (auto-fill). Fallback endpoints still work:

- `GET /api/supervisor/primary-sites?…`
- `GET /api/supervisor/primary-sites/{id}/containers?…`
- `GET /api/supervisor/containers/{id}?…` (also returns `container_type`)

### Activities

```
GET /api/supervisor/evidence/activities
```

Or `activities` inside catalog.

---

## Save Activity (before + after together)

```
POST /api/supervisor/field-records
Content-Type: multipart/form-data
```

### Common fields

| Field | Required | Notes |
|-------|----------|--------|
| `supervisor_cnic` | Yes | 13 digits |
| `kind` | Yes | `activity` |
| `activity` or `activity_code` | Yes | Catalog |
| `zone_code` | Yes | `Zone-4` / `Zone-5` |
| `latitude` / `longitude` | Yes | Or `geo_tag` |
| `remarks` | No | |
| `date` | No | `yyyy-MM-dd`, default today |
| `before` (file) | Yes | **1–2** images. Repeat part name `before`. For photos-only activities these are the only pictures. |
| `after` (file) | Conditional | **Required** for `containers`, `tcp`, `bulk` (**1–2**). **Not required** for all other activities. |

### Container Collection/Clearance only

| Field | Required | Notes |
|-------|----------|--------|
| `container_id` | Yes | Inventory container |
| `container_name` | No | Defaults to container code |
| `container_type` | Yes | `1.1 m3` or `8 m3` (app auto-fill) |
| `vehicle_number` | Yes | |
| `vehicle_type` | Yes | App auto-fill |
| `vehicle_id` | No | |

Do **not** require `uc_code` for this activity.

### Transfer / Bulk / all other non-container activities

| Field | Required | Notes |
|-------|----------|--------|
| `uc_code` | No | Optional union council for the selected zone |

Do **not** require (and app will not send) `container_id`, `container_name`, `container_type`, `vehicle_id`, `vehicle_number`, or `vehicle_type`.

- **`tcp` / `bulk`:** require **before + after** (1–2 each).
- **Remaining activities:** require **1–2 `before` only**; do **not** reject missing `after`.

**One record = one folder.** All before + after files from this multipart POST land under the same `{record_id}` folder.

**Legacy:** if `groups` JSON is sent, the old UC-group activity path still runs.

### cURL — container flow

```bash
curl -X POST "https://cda-swm.asktech.com.pk:5010/api/supervisor/field-records" \
  -H "authkey: CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0" \
  -F "supervisor_cnic=3520212345671" \
  -F "kind=activity" \
  -F "activity_code=containers" \
  -F "zone_code=Zone-4" \
  -F "container_id=501" \
  -F "container_type=1.1 m3" \
  -F "vehicle_number=ICT-1234" \
  -F "vehicle_type=Compactor" \
  -F "latitude=33.6844" \
  -F "longitude=73.0479" \
  -F "remarks=Cleared beat" \
  -F "before=@/path/before1.jpg" \
  -F "after=@/path/after1.jpg"
```

### cURL — Transfer / Bulk (before + after, optional UC)

```bash
curl -X POST "https://cda-swm.asktech.com.pk:5010/api/supervisor/field-records" \
  -H "authkey: CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0" \
  -F "supervisor_cnic=3520212345671" \
  -F "kind=activity" \
  -F "activity_code=tcp" \
  -F "zone_code=Zone-4" \
  -F "uc_code=UC-12" \
  -F "latitude=33.6844" \
  -F "longitude=73.0479" \
  -F "remarks=TCP cleared" \
  -F "before=@/path/before1.jpg" \
  -F "after=@/path/after1.jpg"
```

### cURL — photos-only activities (e.g. Door to Door)

Backend **must accept** without `after` and without `uc_code`.

```bash
curl -X POST "https://cda-swm.asktech.com.pk:5010/api/supervisor/field-records" \
  -H "authkey: CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0" \
  -F "supervisor_cnic=3520212345671" \
  -F "kind=activity" \
  -F "activity_code=dtd" \
  -F "zone_code=Zone-4" \
  -F "latitude=33.6844" \
  -F "longitude=73.0479" \
  -F "remarks=Door to door completed" \
  -F "before=@/path/photo1.jpg" \
  -F "before=@/path/photo2.jpg"
```

### Success `201`

Includes `record_id`, `before[]`, `after[]` (URL arrays), optional container/vehicle/UC fields, `latitude`/`longitude`, `remarks`, `saved_at`.

### List / detail

```
GET /api/supervisor/field-records?supervisor_cnic=&date=&kind=activity
GET /api/supervisor/field-records/{id}?supervisor_cnic=
```

---

## Disk layout (one folder per activity record)

Activity folder slug matches PED evidence catalog (e.g. `door-to-door`, `mech_sweep` → `mechanical-sweeping`).

All photos for that submit (up to 2 before + up to 2 after) stay in the same `{record_id}` folder:

```
D:\SmartSWM\App_Data\uploads\field-records\activity\{activity-folder}\{record_id}\
  {stamp}_before_1.jpg
  {stamp}_before_2.jpg
  {stamp}_after_1.jpg
  {stamp}_after_2.jpg
```

Public:

```
/uploads/field-records/activity/{activity-folder}/{record_id}/{filename}
```

IIS app-pool needs **Modify** on `D:\SmartSWM\App_Data\uploads\field-records`.

---

## Auto-fill contract (container flow only)

| Select | Read-only field | Source |
|--------|-----------------|--------|
| Container | Container type | `container_type` on list/detail |
| Vehicle | Vehicle type | `vehicle_type` on list/catalog |

Inventory types are fixed: **1.1 m3** | **8 m3**.

---

## Flutter wiring (this app)

- **Container Collection/Clearance:** unchanged — Zone → containers + vehicles → GPS → 1–2 before → 1–2 after → submit with container/vehicle
- **Transfer Station / Bulk Waste:** Zone → optional UC → GPS → 1–2 before → 1–2 after → submit (no container/vehicle)
- **All remaining activities:** single screen — Zone → optional UC → GPS → **1–2 photos** → remarks → submit (`before` only, no `after`)
- Submit → **one** `POST /field-records` (`kind=activity`) → **one** `{record_id}` folder
- PED evidence: first **after** when present, else first **before** (decision B)
