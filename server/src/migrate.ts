import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Db } from './db.js';

const sqlDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../sql');

export async function migrate(db: Db): Promise<void> {
  await db.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  const files = (await readdir(sqlDir)).filter((name) => name.endsWith('.sql')).sort();
  for (const file of files) {
    const applied = await db.query<{ id: string }>(`SELECT id FROM schema_migrations WHERE id = $1`, [file]);
    if (applied.rows[0]) continue;
    const sql = await readFile(path.join(sqlDir, file), 'utf8');
    await db.exec(sql);
    await db.query(`INSERT INTO schema_migrations (id) VALUES ($1)`, [file]);
  }
}
