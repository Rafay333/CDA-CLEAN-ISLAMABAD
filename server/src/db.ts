import { mkdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import type { AppConfig } from './config.js';

export type Row = Record<string, unknown>;

export interface Db {
  query<T = Row>(sql: string, params?: unknown[]): Promise<{ rows: T[]; rowCount: number }>;
  exec(sql: string): Promise<void>;
  transaction<T>(fn: (tx: Db) => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

type QueryResult = { rows: Row[]; affectedRows?: number; rowCount?: number | null };

function normalize(result: QueryResult): { rows: Row[]; rowCount: number } {
  const rows = result.rows ?? [];
  const rowCount = result.rowCount ?? result.affectedRows ?? rows.length;
  return { rows, rowCount: Number(rowCount) };
}

function wrap(queryable: {
  query: (sql: string, params?: unknown[]) => Promise<QueryResult>;
  exec?: (sql: string) => Promise<unknown>;
  transaction?: <T>(fn: (tx: { query: (sql: string, params?: unknown[]) => Promise<QueryResult> }) => Promise<T>) => Promise<T>;
  close?: () => Promise<void>;
}): Db {
  const db: Db = {
    async query<T = Row>(sql: string, params: unknown[] = []) {
      return normalize(await queryable.query(sql, params)) as { rows: T[]; rowCount: number };
    },
    async exec(sql) {
      if (queryable.exec) {
        await queryable.exec(sql);
        return;
      }
      await queryable.query(sql);
    },
    async transaction(fn) {
      if (!queryable.transaction) {
        throw new Error('This database connection cannot open a transaction.');
      }
      return queryable.transaction(async (tx) => {
        const inner = wrap({ query: (sql, params) => tx.query(sql, params) });
        inner.transaction = () => {
          throw new Error('Nested transactions are not used.');
        };
        return fn(inner);
      });
    },
    async close() {
      await queryable.close?.();
    },
  };
  return db;
}

export async function openDatabase(config: AppConfig, options?: { memory?: boolean }): Promise<Db> {
  if (!options?.memory && config.databaseUrl) {
    const pool = new pg.Pool({ connectionString: config.databaseUrl });
    return {
      async query<T = Row>(sql: string, params: unknown[] = []) {
        const result = await pool.query(sql, params as never[]);
        return { rows: result.rows as T[], rowCount: result.rowCount ?? result.rows.length };
      },
      async exec(sql) {
        await pool.query(sql);
      },
      async transaction(fn) {
        const client = await pool.connect();
        try {
          await client.query('BEGIN');
          const tx: Db = {
            query: async <T = Row>(sql: string, params: unknown[] = []) => {
              const result = await client.query(sql, params as never[]);
              return { rows: result.rows as T[], rowCount: result.rowCount ?? result.rows.length };
            },
            exec: async (sql) => {
              await client.query(sql);
            },
            transaction: () => {
              throw new Error('Nested transactions are not used.');
            },
            close: async () => {},
          };
          const value = await fn(tx);
          await client.query('COMMIT');
          return value;
        } catch (error) {
          await client.query('ROLLBACK');
          throw error;
        } finally {
          client.release();
        }
      },
      async close() {
        await pool.end();
      },
    };
  }

  if (!options?.memory) await mkdir(config.dataDir, { recursive: true });
  const client = options?.memory ? new PGlite() : new PGlite(config.dataDir);
  await client.waitReady;
  return wrap({
    query: (sql, params) => client.query(sql, params),
    exec: (sql) => client.exec(sql),
    transaction: (fn) => client.transaction(fn),
    close: () => client.close(),
  });
}
