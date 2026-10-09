import sql, { type config as SqlConfig, type ConnectionPool } from 'mssql';
import type { AppConfig } from './config.js';
import { ApiError } from './errors.js';

let pool: ConnectionPool | null = null;

export function sqlConfig(connectionString: string): SqlConfig {
  const map = new Map<string, string>();
  for (const part of connectionString.split(';')) {
    const cut = part.indexOf('=');
    if (cut <= 0) continue;
    map.set(part.slice(0, cut).trim().toLowerCase(), part.slice(cut + 1).trim());
  }
  const server = map.get('server') || map.get('data source');
  const database = map.get('database') || map.get('initial catalog');
  const user = map.get('user id') || map.get('uid');
  const password = map.get('password') || map.get('pwd');
  if (!server || !database || !user || password == null) {
    throw new ApiError(500, 'SMARTSWM', 'SMARTSWM_CONNECTION must include Server, Database, User Id, and Password.');
  }
  return {
    server,
    database,
    user,
    password,
    options: {
      encrypt: (map.get('encrypt') ?? 'true').toLowerCase() !== 'false',
      trustServerCertificate: (map.get('trustservercertificate') ?? 'false').toLowerCase() === 'true',
    },
    connectionTimeout: 15000,
    requestTimeout: 30000,
  };
}

export async function smartSwm(config: AppConfig): Promise<ConnectionPool> {
  if (!config.smartSwmConnection) {
    throw new ApiError(500, 'SMARTSWM', 'SmartSWM is not configured. Set SMARTSWM_CONNECTION in server/.env.');
  }
  if (pool?.connected) return pool;
  pool = await new sql.ConnectionPool(sqlConfig(config.smartSwmConnection)).connect();
  return pool;
}

export function schemaHint(error: unknown): never {
  const message = error instanceof Error ? error.message : String(error);
  if (/Invalid column name|Invalid object name/i.test(message)) {
    throw new ApiError(
      500,
      'SCHEMA',
      'SmartSWM needs the face columns. Run server/smartswm/002_smartswm_face.sql on SmartSWM.',
    );
  }
  throw error instanceof Error ? error : new Error(message);
}
