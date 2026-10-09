import { ApiError } from './errors.js';

export function normalizePhone(input: string): string {
  const digits = input.replace(/\D/g, '');
  let national = digits;
  if (national.startsWith('92')) national = national.slice(2);
  if (national.startsWith('0')) national = national.slice(1);
  if (!/^3\d{9}$/.test(national)) {
    throw new ApiError(400, 'INVALID_PHONE', 'Enter a Pakistani mobile number, for example 03001234567.');
  }
  return `+92${national}`;
}

export function maskPhone(phone: string): string {
  const tail = phone.slice(-4);
  return `+92•••••${tail}`;
}
