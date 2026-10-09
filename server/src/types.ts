export type Role = 'citizen' | 'field_officer' | 'zone_supervisor' | 'directorate_admin' | 'system_admin';

export type UserRecord = {
  id: string;
  role: Role;
  full_name: string;
  phone_e164: string;
  employee_id: string | null;
  password_hash: string | null;
  zone_id: string | null;
  sector_id: string | null;
  language: 'en' | 'ur';
  status: 'active' | 'disabled';
};
