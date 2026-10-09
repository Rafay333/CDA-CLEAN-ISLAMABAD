CREATE TABLE zones (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE sectors (
  id UUID PRIMARY KEY,
  zone_id UUID NOT NULL REFERENCES zones (id),
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  min_lat DOUBLE PRECISION NOT NULL,
  max_lat DOUBLE PRECISION NOT NULL,
  min_lng DOUBLE PRECISION NOT NULL,
  max_lng DOUBLE PRECISION NOT NULL,
  center_lat DOUBLE PRECISION NOT NULL,
  center_lng DOUBLE PRECISION NOT NULL
);

CREATE TABLE users (
  id UUID PRIMARY KEY,
  role TEXT NOT NULL CHECK (role IN (
    'citizen', 'field_officer', 'zone_supervisor', 'directorate_admin', 'system_admin'
  )),
  full_name TEXT NOT NULL,
  phone_e164 TEXT NOT NULL UNIQUE,
  employee_id TEXT UNIQUE,
  password_hash TEXT,
  zone_id UUID REFERENCES zones (id),
  sector_id UUID REFERENCES sectors (id),
  language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'ur')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users (id),
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);

CREATE TABLE categories (
  id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ur TEXT NOT NULL,
  ack_hours INTEGER NOT NULL,
  resolve_hours INTEGER NOT NULL,
  pause_overnight BOOLEAN NOT NULL DEFAULT TRUE,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE streets (
  id UUID PRIMARY KEY,
  sector_id UUID NOT NULL REFERENCES sectors (id),
  name TEXT NOT NULL,
  collection_days TEXT NOT NULL,
  window_start TEXT NOT NULL,
  window_end TEXT NOT NULL
);

CREATE TABLE cases (
  id UUID PRIMARY KEY,
  case_number TEXT NOT NULL UNIQUE,
  reporter_id UUID NOT NULL REFERENCES users (id),
  category_id UUID NOT NULL REFERENCES categories (id),
  status TEXT NOT NULL CHECK (status IN (
    'submitted', 'accepted', 'rejected', 'duplicate', 'assigned',
    'in_progress', 'resolved', 'closed', 'reopened'
  )),
  sector_id UUID NOT NULL REFERENCES sectors (id),
  zone_id UUID NOT NULL REFERENCES zones (id),
  street_text TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  sector_overridden BOOLEAN NOT NULL DEFAULT FALSE,
  ack_due_at TIMESTAMPTZ,
  sla_due_at TIMESTAMPTZ,
  ack_breached BOOLEAN NOT NULL DEFAULT FALSE,
  sla_breached BOOLEAN NOT NULL DEFAULT FALSE,
  duplicate_of_id UUID REFERENCES cases (id),
  rejection_reason TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX cases_zone_status ON cases (zone_id, status);
CREATE INDEX cases_reporter ON cases (reporter_id);

CREATE TABLE case_photos (
  id UUID PRIMARY KEY,
  case_id UUID REFERENCES cases (id),
  kind TEXT NOT NULL CHECK (kind IN ('before', 'after', 'reopen')),
  storage_key TEXT NOT NULL,
  uploaded_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE case_events (
  id UUID PRIMARY KEY,
  case_id UUID NOT NULL REFERENCES cases (id),
  actor_id UUID REFERENCES users (id),
  from_status TEXT,
  to_status TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE assignments (
  id UUID PRIMARY KEY,
  case_id UUID NOT NULL REFERENCES cases (id),
  officer_id UUID NOT NULL REFERENCES users (id),
  assigned_by UUID NOT NULL REFERENCES users (id),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  released_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX assignments_one_active ON assignments (case_id) WHERE active;

CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users (id),
  case_id UUID REFERENCES cases (id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE device_tokens (
  token TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users (id),
  platform TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_log (
  id UUID PRIMARY KEY,
  actor_id UUID,
  action TEXT NOT NULL,
  entity TEXT NOT NULL,
  entity_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE case_counters (
  year INTEGER PRIMARY KEY,
  last_value INTEGER NOT NULL
);
